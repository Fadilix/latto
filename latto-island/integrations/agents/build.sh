#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root/integrations/agents"
go build -trimpath -o "$root/bin/latto-agent" .
