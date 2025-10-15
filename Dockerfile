# Build image
FROM swift:5.9-jammy as build

# Install apt dependencies
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libjemalloc-dev

# Set up build
WORKDIR /build
COPY ./Package.* ./
RUN swift package resolve --skip-update \
    $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

# Copy source and build
COPY . .
RUN swift build -c release --static-swift-stdlib \
    && mv `swift build -c release --show-bin-path` /build/bin

# Production image
FROM ubuntu:jammy

# Make sure all system packages are up to date, and install only essential packages.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
      ca-certificates \
      tzdata \
      libjemalloc2 \
# If your app or its dependencies import FoundationNetworking, also install `libcurl4`.
      libcurl4 \
# If your app or its dependencies import FoundationXML, also install `libxml2`.
      libxml2 \
    && rm -r /var/lib/apt/lists/*

# Create a vapor user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Switch to the new home directory
WORKDIR /app

# Copy built executable and any staged resources from builder
COPY --from=build --chown=vapor:vapor /build/bin /app

# Provide configuration needed by the built-in crash reporter and some sensible default behaviors.
ENV SWIFT_ROOT=/usr

# Improve performance on k8s by defaulting to the multithreaded, multi-queue allocator
ENV SWIFT_CONCURRENCY_BACKEND=workqueue

# Support Malloc logging on Linux, if desired
ENV MALLOC_CONF=prof:true,prof_active:false

# Drop root privileges
USER vapor:vapor

# Start the Vapor service when the image is run.
ENTRYPOINT ["./Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]