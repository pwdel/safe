FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/go/bin:/usr/local/safe-guard-bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin
ARG GO_VERSION=1.25.0
ARG TRUFFLEHOG_VERSION=3.94.1
ARG GOCYCLO_VERSION=latest
ARG GOLANGCI_LINT_VERSION=latest
ARG STATICCHECK_VERSION=latest

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
    amd64) th_arch="amd64" ;; \
    arm64) th_arch="arm64" ;; \
    *) echo "Unsupported architecture for trufflehog install: $arch" >&2; exit 1 ;; \
  esac \
  && curl -fsSL "https://github.com/trufflesecurity/trufflehog/releases/download/v${TRUFFLEHOG_VERSION}/trufflehog_${TRUFFLEHOG_VERSION}_linux_${th_arch}.tar.gz" -o /tmp/trufflehog.tgz \
  && tar -xzf /tmp/trufflehog.tgz -C /tmp \
  && install -m 0755 /tmp/trufflehog /usr/local/bin/trufflehog \
  && rm -f /tmp/trufflehog /tmp/trufflehog.tgz

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
  && ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt \
  && test -x /usr/local/go/bin/go \
  && test -x /usr/local/go/bin/gofmt \
  && test -x /usr/local/bin/gofmt

RUN GOBIN=/usr/local/bin go install "github.com/fzipp/gocyclo/cmd/gocyclo@${GOCYCLO_VERSION}" \
  && GOBIN=/usr/local/bin go install "github.com/golangci/golangci-lint/cmd/golangci-lint@${GOLANGCI_LINT_VERSION}" \
  && GOBIN=/usr/local/bin go install "honnef.co/go/tools/cmd/staticcheck@${STATICCHECK_VERSION}" \
  && command -v /usr/local/bin/gocyclo >/dev/null \
  && /usr/local/bin/golangci-lint version >/dev/null \
  && /usr/local/bin/staticcheck -version >/dev/null

RUN groupadd --gid 10001 agent \
  && useradd --uid 10001 --gid 10001 --create-home --shell /bin/bash agent \
  && mkdir -p /workspace /home/agent/.tmp/go-build /home/agent/.codex \
  && chown -R agent:agent /workspace /home/agent/.tmp /home/agent/.codex

ENV HOME=/home/agent
ENV CODEX_HOME=/home/agent/.codex
ENV TMPDIR=/home/agent/.tmp
ENV GOTMPDIR=/home/agent/.tmp/go-build
ENV XDG_CACHE_HOME=/home/agent/.tmp/xdg-cache
ENV NPM_CONFIG_CACHE=/home/agent/.tmp/npm-cache

RUN cat > /home/agent/.gitconfig <<'EOF'
[safe]
  directory = *
[core]
  hooksPath = /home/agent/.git-hooks
EOF

RUN mkdir -p /home/agent/.git-hooks \
  && cat > /home/agent/.git-hooks/pre-commit <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${SAFE_SKIP_SECRET_SCAN:-0}" == "1" ]]; then
  exit 0
fi
if [[ ",${SKIP:-}," == *",trufflehog,"* ]]; then
  exit 0
fi
if ! command -v trufflehog >/dev/null 2>&1; then
  echo "pre-commit blocked: trufflehog is not available in this runner." >&2
  exit 1
fi

mapfile -t staged_files < <(git diff --cached --name-only --diff-filter=ACMR)
if [[ "${#staged_files[@]}" -eq 0 ]]; then
  exit 0
fi

scan_targets=()
for file in "${staged_files[@]}"; do
  if [[ -e "$file" ]]; then
    scan_targets+=("$file")
  fi
done

if [[ "${#scan_targets[@]}" -eq 0 ]]; then
  exit 0
fi

echo "Running trufflehog pre-commit scan..."
trufflehog filesystem --results=verified,unknown --fail "${scan_targets[@]}"
EOF

RUN cat > /home/agent/.git-hooks/pre-push <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

remote_name="${1:-}"
if [[ "$remote_name" != "origin" ]]; then
  echo "Push blocked: only the origin remote may be used from this runner." >&2
  exit 1
fi

if git remote get-url upstream >/dev/null 2>&1; then
  origin_url="$(git remote get-url origin)"
  upstream_url="$(git remote get-url upstream)"
  if [[ "$origin_url" == "$upstream_url" ]]; then
    echo "Push blocked: origin and upstream point to the same repository." >&2
    exit 1
  fi
fi

if [[ "${SAFE_SKIP_SECRET_SCAN:-0}" == "1" ]]; then
  exit 0
fi
if ! command -v trufflehog >/dev/null 2>&1; then
  echo "pre-push blocked: trufflehog is not available in this runner." >&2
  exit 1
fi

if git rev-parse --verify "${remote_name}/main" >/dev/null 2>&1; then
  scan_base="${remote_name}/main"
elif git rev-parse --verify "${remote_name}/master" >/dev/null 2>&1; then
  scan_base="${remote_name}/master"
else
  scan_base="$(git rev-list --max-parents=0 HEAD | tail -n 1)"
fi

echo "Running trufflehog pre-push scan..."
trufflehog git "file://$(pwd)" --since-commit "$scan_base" --branch HEAD --results=verified,unknown --fail
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
  && chmod 0444 /home/agent/.bashrc /home/agent/.gitconfig \
  && chmod 0555 /home/agent/.git-hooks \
  && chmod 0555 /home/agent/.git-hooks/pre-commit /home/agent/.git-hooks/pre-push \
  && chmod 0700 /home/agent/.tmp /home/agent/.tmp/go-build \
  && /usr/bin/chown -R root:root /home/agent/.bashrc /home/agent/.gitconfig /home/agent/.git-hooks \
  && /usr/bin/chown -R agent:agent /home/agent/.tmp /home/agent/.codex \
  && /usr/bin/chown root:root /home/agent \
  && chmod 0555 /home/agent

WORKDIR /workspace
USER agent
