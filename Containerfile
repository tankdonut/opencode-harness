# syntax=docker/dockerfile:1.4

# ============================================
# OpenCode Harness Container Image
# ============================================
# Build with specific OpenCode version:
#   podman build --build-arg OPENCODE_VERSION=1.2.27 -t opencode-harness:1.2.27 -f Containerfile .
#
# Image tags include OpenCode version for traceability:
#   opencode-harness:1.2.27  - specific version
#   opencode-harness:latest  - current default
# ============================================

FROM ghcr.io/tankdonut/tools:latest AS tools

FROM docker.io/library/ubuntu:24.04

# Build arguments
ARG DEBIAN_FRONTEND=noninteractive
ARG OPENCODE_VERSION=1.2.27
ARG TARGETARCH=amd64
ARG TARGETVARIANT=

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    nodejs \
    npm \
    python3 \
    python3-pip \
    unzip \
    yq \
    && rm -rf /var/lib/apt/lists/*

# Install bun runtime for oh-my-opencode
# Using npm to install bun globally (cleaner than curl|bash in container)
RUN npm install -g bun

# Copy vendor binaries from tools stage
COPY --from=tools /dist/ /vendor/bin/

# Download and install OpenCode from GitHub releases
# This happens at build time for reproducibility
RUN set -eux; \
    # Determine architecture mapping \
    case "$(uname -m)" in \
    x86_64)  OPENCODE_ARCH="x64" ;; \
    aarch64) OPENCODE_ARCH="arm64" ;; \
    *)       OPENCODE_ARCH="x64" ;; \
    esac; \
    \
    # Construct download URL \
    OPENCODE_RELEASE_URL="https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${OPENCODE_ARCH}.tar.gz"; \
    \
    echo "Downloading OpenCode ${OPENCODE_VERSION} for ${OPENCODE_ARCH}..."; \
    curl -fsSL "${OPENCODE_RELEASE_URL}" -o /tmp/opencode.tar.gz; \
    \
    # Verify download succeeded \
    if [ ! -s /tmp/opencode.tar.gz ]; then \
    echo "ERROR: Failed to download OpenCode from ${OPENCODE_RELEASE_URL}"; \
    exit 1; \
    fi; \
    \
    # Extract to vendor bin \
    tar -xzf /tmp/opencode.tar.gz -C /vendor/bin; \
    chmod +x /vendor/bin/opencode; \
    \
    # Verify installation \
    /vendor/bin/opencode --version; \
    \
    # Cleanup \
    rm -f /tmp/opencode.tar.gz; \
    \
    echo "✓ OpenCode ${OPENCODE_VERSION} installed successfully";

# Create non-root user with HOME=/workspace
RUN useradd -m -d /workspace -u 1001 -s /bin/bash opencode || useradd -m -d /workspace -s /bin/bash opencode

WORKDIR /workspace

# Copy configuration files
COPY --chown=opencode:opencode opencode.json /app/opencode.json
COPY --chown=opencode:opencode etc/opencode/opencode.jsonc /etc/opencode/opencode.jsonc
COPY --chown=opencode:opencode modules/ /workspace/modules/
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# Environment configuration
ENV PATH="/vendor/bin:${PATH}" \
    OPENCODE_CONFIG="/workspace/.config/opencode/opencode.json" \
    OPENCODE_VERSION="${OPENCODE_VERSION}"

# Add labels for image metadata
LABEL org.opencontainers.image.title="OpenCode Harness" \
    org.opencontainers.image.description="Containerized OpenCode environment with production-ready agents and skills" \
    org.opencontainers.image.version="${OPENCODE_VERSION}" \
    org.opencontainers.image.source="https://github.com/tankdonut/opencode-harness" \
    opencode.version="${OPENCODE_VERSION}"

USER opencode

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
