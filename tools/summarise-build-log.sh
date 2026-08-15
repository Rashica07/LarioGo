#!/usr/bin/env bash
#
# Print a readable summary of a failed Swift build or test log.
#
# Swift re-emits every warning once per compiled file, so a failing build easily
# produces 30,000+ lines. GitHub's web log viewer virtualises those, which makes
# the actual failure genuinely unreachable without downloading the archive.
#
# The first version of this only matched `file.swift:LINE:COL: error:` and
# printed nothing when the backend failed on a linker/driver error instead —
# an empty summary that looked like "no errors" on a failed build. So this
# casts wider AND always prints the tail, because the fatal reason is almost
# always in the last few lines even when no pattern matches.
#
# Usage: summarise-build-log.sh <logfile>
set -uo pipefail

log="${1:?usage: summarise-build-log.sh <logfile>}"

if [[ ! -s "$log" ]]; then
    echo "::error::Build log '$log' is missing or empty."
    exit 0
fi

echo "::group::Compiler errors (unique)"
# Source-located diagnostics, path-trimmed so they are readable.
compiler_errors=$(
    grep -E '[^ ]+\.swift:[0-9]+:[0-9]+: error:' "$log" 2>/dev/null \
        | sed -E 's|.*/(Sources\|Tests)/|\1/|' \
        | sort -u | head -60
)
if [[ -n "$compiler_errors" ]]; then
    echo "$compiler_errors"
else
    echo "(none matched the source-location pattern)"
fi
echo "::endgroup::"

echo "::group::Other errors (linker, driver, dependencies)"
# Anything error-shaped that is not a source diagnostic and not the generic
# driver abort, which is noise on its own.
other=$(
    grep -iE '(^|[^a-z])(error|fatal|cannot find|no such module|undefined symbol|linker command failed|unresolved)' "$log" 2>/dev/null \
        | grep -vE '[^ ]+\.swift:[0-9]+:[0-9]+: error:' \
        | grep -vE '^error: fatalError$' \
        | sed -E 's|/__w/[^ ]*/(Sources\|Tests)/|\1/|' \
        | sort -u | head -40
)
if [[ -n "$other" ]]; then
    echo "$other"
else
    echo "(none)"
fi
echo "::endgroup::"

# Always shown, never collapsed: when every pattern above misses, this is what
# actually tells you what happened.
echo "::group::Last 40 lines"
tail -n 40 "$log"
echo "::endgroup::"

echo "Log line count: $(wc -l < "$log")"
