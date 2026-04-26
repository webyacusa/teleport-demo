#!/usr/bin/env bash
set -euo pipefail

CLUSTER=${CLUSTER:-bamoe-demo}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

build_and_load() {
  local name=$1
  local dir=$2
  local tag="teleport-demo/${name}:1.0.0"

  echo ""
  echo "🔨  Building ${name}…"
  (cd "${dir}" && docker build -t "${tag}" .)

  echo "📦  Loading ${tag} into kind cluster '${CLUSTER}'…"
  kind load docker-image "${tag}" --name "${CLUSTER}"
}

echo "=========================================="
echo "  Building all demo container images"
echo "=========================================="

build_and_load "bamoe-service"      "${ROOT}/services/bamoe-service"
build_and_load "teleport-adapter"   "${ROOT}/services/teleport-adapter"
build_and_load "sailpoint-mock"     "${ROOT}/services/sailpoint-mock"
build_and_load "training-lms-mock"  "${ROOT}/services/training-lms-mock"
build_and_load "notification-mock"  "${ROOT}/services/notification-mock"
build_and_load "operator-ui"        "${ROOT}/services/operator-ui"

echo ""
echo "✅  All images built and loaded."
echo "   Next: ./setup/03-deploy.sh"
