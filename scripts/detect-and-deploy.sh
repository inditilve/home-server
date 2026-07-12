#!/usr/bin/env bash
# detect-and-deploy.sh
# Detects which service stacks changed in the latest commit and deploys them.
# Writes a GITHUB_OUTPUT variable `deployed_stacks` with a comma-separated list
# of deployed stack paths, or "none" if nothing was affected.

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git -C "$(dirname "$0")" rev-parse --show-toplevel)}"
cd "$REPO_ROOT"

# Get list of changed files between last two commits
CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
echo "Changed files:"
echo "$CHANGED_FILES"

# Known stacks in priority order (most specific first)
STACKS=(
  "media/apps/immich"
  "media/apps"
  "media/services"
  "dashboard"
  "monitoring"
  "networking"
)

DEPLOYED=()

for STACK in "${STACKS[@]}"; do
  # Check if any changed file falls under this stack
  if echo "$CHANGED_FILES" | grep -q "^${STACK}/"; then
    # Skip if a more specific sub-stack was already deployed
    SKIP=false
    for DONE in "${DEPLOYED[@]}"; do
      if [[ "$DONE" == "${STACK}/"* ]]; then
        SKIP=true
        break
      fi
    done

    if [ "$SKIP" = false ] && [ -f "${STACK}/docker-compose.yaml" ]; then
      echo "--- Deploying stack: $STACK ---"
      cd "${REPO_ROOT}/${STACK}"
      docker compose pull
      docker compose up -d --build
      cd "$REPO_ROOT"
      DEPLOYED+=("$STACK")
    fi
  fi
done

if [ ${#DEPLOYED[@]} -eq 0 ]; then
  echo "No service stacks affected by this commit."
  echo "deployed_stacks=none" >> "${GITHUB_OUTPUT:-/dev/null}"
else
  DEPLOYED_STR=$(IFS=', '; echo "${DEPLOYED[*]}")
  echo "deployed_stacks=${DEPLOYED_STR}" >> "${GITHUB_OUTPUT:-/dev/null}"
fi
