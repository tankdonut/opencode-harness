FROM ghcr.io/tankdonut/tools:latest AS tools

FROM docker.io/library/ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG OPENCODE_VERSION=1.0.0

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    jq \
    nodejs \
    npm \
    python3 \
    python3-pip \
    yq \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1001 -s /bin/bash opencode || useradd -m -s /bin/bash opencode

COPY --from=tools /dist/ /vendor/bin/

WORKDIR /app

COPY --chown=opencode:opencode opencode.json /app/opencode.json
COPY --chown=opencode:opencode etc/opencode/opencode.jsonc /etc/opencode/opencode.jsonc
COPY --chown=opencode:opencode modules/ /app/modules/
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint

ENV PATH="/vendor/bin:${PATH}" \
    OPENCODE_CONFIG="/app/opencode.json" \
    OPENCODE_VERSION="${OPENCODE_VERSION}"

USER opencode

RUN /usr/local/bin/entrypoint

CMD ["/bin/bash"]
