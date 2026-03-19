FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/agent

RUN apt-get update && apt-get install -y \
  bash \
  build-essential \
  ca-certificates \
  curl \
  gh \
  git \
  golang-go \
  jq \
  make \
  nodejs \
  npm \
  python3 \
  python3-pip \
  python3-venv \
  ripgrep \
  zsh \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 10001 agent \
  && useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash agent \
  && mkdir -p /workspace \
  && chown -R agent:agent /workspace /home/agent

COPY safe-init-auth.sh /usr/local/bin/safe-init-auth
RUN chmod 0755 /usr/local/bin/safe-init-auth

WORKDIR /workspace
USER agent
