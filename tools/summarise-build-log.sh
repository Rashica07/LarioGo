#!/usr/bin/env bash
#
# Print a readable summary of a failed Swift build or test log.
#
# Swift re-emits every warning once per compiled file, so a failing build easily
# produces 35,000+ lines. Two things follow from that, both learned the hard way:
#
#   1. A narrow grep is worse than none. The first version only matched
#      `file.swift:LINE:COL: error:`, so when the backend failed on a linker or
#      driver error it printed nothing — an empty summary on a failed build
#      reads as "no errors". This now casts wider and always prints the tail.
#
#   2. Printing to stdout is not enough. GitHub's web log viewer virtualises
#      long logs, so output buried at line ~36,000 is unreachable in a browser
#      even when it is technically in the log. Everything here is therefore
#      also written to $GITHUB_STEP_SUMMARY, which renders as markdown on the
#      run page, outside the log viewer.
#
# Usage: summarise-build-log.sh <logfile>
set -uo pipefail

log="${1:?usage: summarise-build-log.sh <logfile>}"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"

emit() {
    echo "$1"
    echo "$1" >> "$summary"
}

if [[ ! -s "$log" ]]; then
    echo "::error::Build log '$log' is missing or empty."
    emit "### Build failed, but the log was empty"
    exit 0
fi

emit "### Build failure summary"
emit ""
emit "\`$(basename "$log")\` — $(wc -l < "$log") lines"
emit ""

compiler_errors=$(
    grep -E '[^ ]+\.swift:[0-9]+:[0-9]+: error:' "$log" 2>/dev/null \
        | sed -E 's|.*/(Sources\|Tests)/|\1/|' \
        | sort -u | head -60
)

other=$(
    grep -iE '(^|[^a-z])(error|fatal|cannot find|no such module|undefined symbol|linker command failed|unresolved)' "$log" 2>/dev/null \
        | grep -vE '[^ ]+\.swift:[0-9]+:[0-9]+: error:' \
        | grep -vE '^error: fatalError$' \
        | sed -E 's|/__w/[^ ]*/(Sources\|Tests)/|\1/|' \
        | cut -c1-300 \
        | sort -u | head -40
)

emit "#### Compiler errors"
emit '```'
if [[ -n "$compiler_errors" ]]; then
    emit "$compiler_errors"
else
    emit "(none matched the source-location pattern)"
fi
emit '```'

emit "#### Other errors (linker, driver, dependencies)"
emit '```'
if [[ -n "$other" ]]; then
    emit "$other"
else
    emit "(none)"
fi
emit '```'

# Always included: when every pattern above misses, this is what actually says
# what happened.
emit "#### Last 40 lines"
emit '```'
emit "$(tail -n 40 "$log" | cut -c1-300)"
emit '```'
