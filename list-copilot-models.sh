#!/bin/bash

# Script to list GitHub Copilot models in copilot-config.yaml format
# Usage: ./list-copilot-models.sh [--enabled-only]

set -e

cd "$(dirname "$0")"

GITHUB_TOKEN_FILE="litellm-data/github_copilot/access-token"
ENABLED_ONLY=false
VSCODE_VERSION="vscode/1.111.0"

# Parse arguments
if [[ "$1" == "--enabled-only" ]]; then
    ENABLED_ONLY=true
fi

# Check if GitHub token exists
if [[ ! -f "$GITHUB_TOKEN_FILE" ]]; then
    echo "❌ GitHub Copilot token not found at $GITHUB_TOKEN_FILE"
    echo "   Run 'make start' first to authenticate with GitHub"
    exit 1
fi

# Read the token (strip any whitespace)
GITHUB_TOKEN=$(cat "$GITHUB_TOKEN_FILE" | tr -d '\n\r ')

echo "# GitHub Copilot Models Available"
echo "# Generated on $(date)"
echo "# Usage: Copy the desired models to your copilot-config.yaml"
echo ""

echo "litellm_settings:"
echo "  drop_params: true"
echo ""

# Fetch models and format for YAML
if [[ "$ENABLED_ONLY" == "true" ]]; then
    echo "# Showing only enabled models"
    FILTER='select(.policy.state == "enabled" or .policy == null)'
else
    echo "# Showing all models (enabled and unconfigured)"
    FILTER='.'
fi

POWERFUL_MODEL_FILTERS='select(.id | startswith("claude") or startswith("gpt-5") or startswith("gemini"))'

echo ""
echo "model_list:"

curl -s -H "Authorization: Bearer $GITHUB_TOKEN" https://api.enterprise.githubcopilot.com/models | \
jq -r '.data[] | select(.capabilities.type == "chat") | '"$FILTER"' | '"$POWERFUL_MODEL_FILTERS"' |
"  - model_name: " + .id + "
    litellm_params:
      model: github_copilot/" + .id + "
      extra_headers: {\"Editor-Version\": \"'$VSCODE_VERSION'\", \"Copilot-Integration-Id\": \"vscode-chat\"}
    # " + .name + " (" + .vendor + ") - " + (.policy.state // "enabled") + "
    # Max prompt tokens: " + (.capabilities.limits.max_prompt_tokens | tostring) + ", Max output tokens: " + (.capabilities.limits.max_output_tokens | tostring) + ", Model context window: " + (.capabilities.limits.max_context_window_tokens | tostring) + "
"'

echo ""
echo "# To use these models:"
echo "# 1. Copy desired model entries to your copilot-config.yaml"
echo "# 2. Restart LiteLLM: make stop && make start"
echo "# 3. Test with: make test"
