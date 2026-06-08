#!/usr/bin/env bash
set -euo pipefail

state="${1:?usage: github-status.sh pending|success|failure}"

curl -fsS -X POST \
  -H "Authorization: Bearer ${GITHUB_STATUS_TOKEN:?}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${GITHUB_REPO:?}/statuses/${CI_COMMIT_SHA:?}" \
  -d "$(jq -n \
    --arg state "$state" \
    --arg target_url "${CI_PIPELINE_URL:-}" \
    --arg description "build all hosts + attic push" \
    '{state: $state, context: "ci/woodpecker", target_url: $target_url, description: $description}')"
