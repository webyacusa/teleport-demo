#!/usr/bin/env bash
set -euo pipefail
CLUSTER=${CLUSTER:-bamoe-demo}

echo "🗑   Deleting kind cluster '${CLUSTER}'…"
kind delete cluster --name "${CLUSTER}" || true
echo "✅  Cleanup complete."
