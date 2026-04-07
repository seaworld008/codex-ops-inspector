FROM node:24-bookworm-slim

ARG CODEX_VERSION=0.118.0
ARG KUBECTL_VERSION=v1.35.3
ARG HELM_VERSION=v4.1.3

ENV DEBIAN_FRONTEND=noninteractive \
    CODEX_HOME=/root/.codex \
    CODEX_MODEL=gpt-5.4 \
    CODEX_BASE_URL=https://your-openai-compatible-endpoint.example.com \
    INSPECT_OUTPUT_DIR=/workspace/output \
    INSPECTION_TARGET=linux

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        jq \
        less \
        openssh-client \
        procps \
        python3 \
        python3-pip \
        tar \
        gzip \
        unzip \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g "@openai/codex@${CODEX_VERSION}"

RUN curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl

RUN curl -fsSLo /tmp/helm.tgz "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
    && tar -xzf /tmp/helm.tgz -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm \
    && rm -rf /tmp/helm.tgz /tmp/linux-amd64

WORKDIR /workspace

COPY package.json ./
COPY package-lock.json ./
RUN npm install --omit=dev

COPY config ./config
COPY prompts ./prompts
COPY scripts ./scripts
COPY skills ./skills
COPY k8s ./k8s

RUN chmod +x /workspace/scripts/*.sh /workspace/scripts/lib/*.sh \
    && mkdir -p "${CODEX_HOME}" "${INSPECT_OUTPUT_DIR}"

ENTRYPOINT ["bash", "/workspace/scripts/run-inspection.sh"]
