#!/usr/bin/env bash

set -euo pipefail

echo "Running yamllint..."
uv run yamllint \
    ansible_collections \
    inventory \
    playbooks \
    requirements.yml

echo "Running ansible-lint..."
uv run ansible-lint
