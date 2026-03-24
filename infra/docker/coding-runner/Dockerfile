FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/agent
ENV PATH=/usr/local/safe-guard-bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

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
COPY safe-guard-command.sh /usr/local/bin/safe-guard-command
COPY safe-shellrc /home/agent/.bashrc
RUN chmod 0755 /usr/local/bin/safe-init-auth /usr/local/bin/safe-guard-command \
  && mkdir -p /usr/local/safe-guard-bin \
  && ln -sf /usr/local/bin/safe-guard-command /usr/local/safe-guard-bin/rm \
  && ln -sf /usr/local/bin/safe-guard-command /usr/local/safe-guard-bin/chmod \
  && ln -sf /usr/local/bin/safe-guard-command /usr/local/safe-guard-bin/chown \
  && ln -sf /usr/local/bin/safe-guard-command /usr/local/safe-guard-bin/dd \
  && ln -sf /usr/local/bin/safe-guard-command /usr/local/safe-guard-bin/mkfs \
  && ln -sf /usr/local/bin/safe-guard-command /usr/local/safe-guard-bin/fdisk \
  && ln -sf /usr/local/bin/safe-guard-command /usr/local/safe-guard-bin/sfdisk \
  && ln -sf /usr/local/bin/safe-guard-command /usr/local/safe-guard-bin/parted \
  && ln -sf /usr/local/bin/safe-guard-command /usr/local/safe-guard-bin/mount \
  && ln -sf /usr/local/bin/safe-guard-command /usr/local/safe-guard-bin/umount \
  && chown agent:agent /home/agent/.bashrc

WORKDIR /workspace
USER agent
