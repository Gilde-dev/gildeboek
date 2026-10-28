#!/usr/bin/env bash
# Validates registry.yaml and skills/. Needs bash, python3 and PyYAML (no yq).
# Optional argument: the root directory to validate (default: this repo).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$here/validate.py" "${1:-$here/..}"
