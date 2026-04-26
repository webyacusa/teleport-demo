#!/usr/bin/env bash
# Checks (and where possible, installs) the host-side tools the demo needs.
# This is the only script that touches your laptop directly. Everything else
# runs inside Docker / Kubernetes.
#
# Tools required on the host:
#   docker   — runs containers + builds images
#   kind     — local Kubernetes cluster
#   kubectl  — talks to the cluster
#   tsh      — Teleport client (only needed for the live `tsh login` demo step)
#
# NOT required on the host (they run inside Docker):
#   Java, Maven, Node.js, tctl, the BAMOE runtime — all bundled in container images

set -euo pipefail

OS="$(uname -s)"
ARCH="$(uname -m)"
PLATFORM_OK=true

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }

check() {
  local name=$1 cmd=$2 install_hint=$3
  if command -v "$cmd" >/dev/null 2>&1; then
    green "  ✓ ${name} found: $(command -v "$cmd")"
    return 0
  else
    yellow "  ✗ ${name} not found"
    echo  "      install: ${install_hint}"
    return 1
  fi
}

echo "🔍  Checking host-side prerequisites…"
echo ""

ALL_OK=true

case "$OS" in
  Linux)
    HINT_DOCKER="https://docs.docker.com/engine/install/ — or:  curl -fsSL https://get.docker.com | sh"
    HINT_KIND="go install sigs.k8s.io/kind@latest  — or download from https://kind.sigs.k8s.io/"
    HINT_KUBECTL="https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
    HINT_TSH="curl https://goteleport.com/static/install.sh | bash -s 15.4.0"
    ;;
  Darwin)
    HINT_DOCKER="brew install --cask docker  (or download Docker Desktop)"
    HINT_KIND="brew install kind"
    HINT_KUBECTL="brew install kubectl"
    HINT_TSH="brew install teleport"
    ;;
  *)
    yellow "  ⚠  Unsupported host OS: $OS — proceed at your own risk."
    HINT_DOCKER="see https://docs.docker.com/engine/install/"
    HINT_KIND="see https://kind.sigs.k8s.io/"
    HINT_KUBECTL="see https://kubernetes.io/docs/tasks/tools/"
    HINT_TSH="see https://goteleport.com/docs/installation/"
    ;;
esac

check "Docker"   docker   "${HINT_DOCKER}"   || ALL_OK=false
check "kind"     kind     "${HINT_KIND}"     || ALL_OK=false
check "kubectl"  kubectl  "${HINT_KUBECTL}"  || ALL_OK=false

echo ""
echo "🔍  Checking optional tools…"
echo ""
if check "tsh (Teleport client, optional — needed for live login demo)" tsh "${HINT_TSH}"; then
  TSH_VER="$(tsh version 2>/dev/null | head -1 || echo unknown)"
  echo  "      version: ${TSH_VER}"
fi

echo ""
if [ "$ALL_OK" = true ]; then
  green "✅  Host-side prerequisites are in place."
  echo ""
  echo "   Note: Java, Maven, Node.js, the BAMOE runtime, and tctl are NOT"
  echo "   needed on your host — they all run inside Docker images that"
  echo "   02-build-images.sh and 03-deploy.sh will pull or build."
  echo ""
  echo "   Next: ./setup/01-setup-kind.sh"
else
  red "❌  One or more required tools are missing. Install them and re-run this script."
  exit 1
fi

# Sanity-check Docker is actually running
if ! docker info >/dev/null 2>&1; then
  red "❌  Docker is installed but not running. Start Docker Desktop / dockerd and try again."
  exit 1
fi
