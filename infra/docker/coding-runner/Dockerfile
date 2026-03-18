FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
  bash \
  ca-certificates \
  curl \
  git \
  jq \
  nodejs \
  npm \
  python3 \
  python3-pip \
  python3-venv \
  ripgrep \
  zsh \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
