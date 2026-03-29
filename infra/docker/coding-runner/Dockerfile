FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/go/bin:/usr/local/safe-guard-bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin
ARG GO_VERSION=1.25.0

RUN apt-get update && apt-get install -y \
  bash \
  build-essential \
  ca-certificates \
  curl \
  gh \
  git \
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

RUN npm install -g @openai/codex

RUN arch="$(dpkg --print-architecture)" \
  && case "$arch" in \
    amd64) go_arch="amd64" ;; \
    arm64) go_arch="arm64" ;; \
    *) echo "Unsupported architecture for Go install: $arch" >&2; exit 1 ;; \
  esac \
  && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${go_arch}.tar.gz" -o /tmp/go.tgz \
  && rm -rf /usr/local/go \
  && tar -C /usr/local -xzf /tmp/go.tgz \
  && rm -f /tmp/go.tgz \
  && ln -sf /usr/local/go/bin/go /usr/local/bin/go \
  && ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

RUN groupadd --gid 10001 agent \
  && useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash agent \
  && mkdir -p /workspace /home/agent/.tmp/go-build /home/agent/.codex \
  && chown -R agent:agent /workspace /home/agent

ENV HOME=/home/agent
ENV CODEX_HOME=/home/agent/.codex
ENV TMPDIR=/home/agent/.tmp
ENV GOTMPDIR=/home/agent/.tmp/go-build

RUN cat > /home/agent/.gitconfig <<'EOF'
[safe]
  directory = *
EOF

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
  && chown agent:agent /home/agent/.bashrc /home/agent/.gitconfig

WORKDIR /workspace
USER agent
