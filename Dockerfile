# --- Base stage: Install build dependencies ---
    FROM swift:5.9-jammy as base
    RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
        && apt-get -q update \
        && apt-get -q dist-upgrade -y \
        && apt-get install -y libjemalloc-dev
    
    # --- Development stage ---
    FROM base as dev
    WORKDIR /app
    COPY . .
    RUN swift package resolve
    # Optionally install dev tools, debuggers, etc.
    RUN apt-get install -y git curl
    # Default command for dev: start the app in debug mode
    CMD ["swift", "run"]
    
    # --- Test stage ---
    FROM base as test
    WORKDIR /app
    COPY . .
    RUN swift package resolve
    # Run tests
    CMD ["swift", "test"]
    
    # --- Production stage ---
    FROM ubuntu:jammy as prod
    RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
        && apt-get -q update \
        && apt-get -q dist-upgrade -y \
        && apt-get -q install -y \
          ca-certificates \
          tzdata \
          libjemalloc2 \
          libcurl4 \
          libxml2 \
        && rm -r /var/lib/apt/lists/*
    RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor
    WORKDIR /app
    COPY --from=base /build /app
    RUN swift build -c release --static-swift-stdlib \
        && mv `swift build -c release --show-bin-path`/* /app/
    USER vapor:vapor
    ENTRYPOINT ["./Run"]
    CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
    