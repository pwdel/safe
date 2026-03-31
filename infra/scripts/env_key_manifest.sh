#!/usr/bin/env bash

# Central manifest for runtime and Terraform env key contracts.
# Keep all supported keys/file names here so check/render behavior stays aligned.

RUNTIME_PRIMARY_ENV_FILE="agent.env"
RUNTIME_SPLIT_ENV_FILES=(
  github.env
  codex.env
  claude.env
  openai.env
)
RUNTIME_ALLOWED_KEYS=(
  GH_TOKEN
  GITHUB_TOKEN
  OPENAI_API_KEY
  OPENAI_ORG_ID
  OPENAI_BASE_URL
  ANTHROPIC_API_KEY
  ANTHROPIC_BASE_URL
)
RUNTIME_GITHUB_AUTH_KEYS=(
  GH_TOKEN
  GITHUB_TOKEN
)
RUNTIME_MODEL_AUTH_KEYS=(
  OPENAI_API_KEY
  ANTHROPIC_API_KEY
)

TERRAFORM_ENV_FILE="terraform.env"
TERRAFORM_REQUIRED_KEYS=(
  TF_VAR_do_token
)
TERRAFORM_OPTIONAL_KEYS=(
  TF_VAR_region
  TF_VAR_droplet_size
  TF_VAR_allowed_ssh_cidrs
)

TASK_SPEC_ENV_FILE="task-spec.env"
TASK_SPEC_REQUIRED_KEYS=(
  SAFE_TASK_SPEC_REPO
  SAFE_TASK_SPEC_REF
)
TASK_SPEC_OPTIONAL_KEYS=(
  SAFE_TASK_SPEC_DIR
  SAFE_TASK_SETUP_CMD
  SAFE_TASK_CODEX_MODE
  SAFE_TASK_RUNNER_BIN
  SAFE_TASK_TARGET_FORK_URL
  SAFE_TASK_TARGET_UPSTREAM_URL
  SAFE_TASK_TARGET_DIR
  SAFE_TASK_SANDBOX_BRANCH
  SAFE_TASK_SANDBOX_BASE_REF
)
TASK_SPEC_ALLOWED_KEYS=(
  SAFE_TASK_SPEC_REPO
  SAFE_TASK_SPEC_REF
  SAFE_TASK_SPEC_DIR
  SAFE_TASK_SETUP_CMD
  SAFE_TASK_CODEX_MODE
  SAFE_TASK_RUNNER_BIN
  SAFE_TASK_TARGET_FORK_URL
  SAFE_TASK_TARGET_UPSTREAM_URL
  SAFE_TASK_TARGET_DIR
  SAFE_TASK_SANDBOX_BRANCH
  SAFE_TASK_SANDBOX_BASE_REF
)

env_manifest_contains() {
  local needle="$1"
  shift || true
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

env_manifest_join() {
  local delimiter="$1"
  shift || true
  local first=1
  local item
  for item in "$@"; do
    if (( first == 1 )); then
      printf '%s' "$item"
      first=0
    else
      printf '%s%s' "$delimiter" "$item"
    fi
  done
}
