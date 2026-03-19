FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/agent

RUN apt-get update && apt-get install -y \
  bash \
  build-essential \
  ca-certificates \
  curl \
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

WORKDIR /workspace
USER agent
