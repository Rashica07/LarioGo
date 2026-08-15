# ==================== Build ====================
FROM swift:5.9-jammy AS build

WORKDIR /build

# Resolve dependencies first so the layer caches across source-only changes.
COPY ./Package.swift ./
RUN swift package resolve

COPY . .
RUN swift build -c release --static-swift-stdlib

# Collect everything the runtime image needs into one directory.
WORKDIR /staging
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/App" ./ \
    && find -L "$(swift build --package-path /build -c release --show-bin-path)/" \
         -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# ==================== Run ====================
FROM ubuntu:jammy

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/*

# Never run the service as root.
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor
WORKDIR /app
COPY --from=build --chown=vapor:vapor /staging /app
USER vapor:vapor

EXPOSE 8080

# Migrations run as an explicit deploy step, not implicitly on boot, so a bad
# migration cannot take the service down on every restart.
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
