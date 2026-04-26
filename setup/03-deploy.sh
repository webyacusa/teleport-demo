#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
K8S="${ROOT}/k8s"
IDENTITY_FILE="${IDENTITY_FILE:-/tmp/teleport-bot-identity}"
PROXY="${TELEPORT_PROXY:-yellow-glitter.trial.teleport.sh}"

if [ ! -s "${IDENTITY_FILE}" ]; then
  echo "❌  Bot identity file not found at ${IDENTITY_FILE}"
  echo "    Run ./setup/02b-bootstrap-tenant.sh first."
  exit 1
fi

echo "🚀  Applying Kubernetes manifests…"

echo "   • namespace"
kubectl apply -f "${K8S}/00-namespace.yaml"

echo "   • storing bot identity file as a Kubernetes Secret"
kubectl -n bamoe-demo delete secret teleport-bot-identity --ignore-not-found
kubectl -n bamoe-demo create secret generic teleport-bot-identity \
  --from-file=identity="${IDENTITY_FILE}"

echo "   • Teleport adapter (skipping placeholder Secret in manifest)"
awk '/^---$/{c++} c>=2 {print}' "${K8S}/15-teleport-adapter.yaml" | kubectl apply -f -

echo "   • Mocks (SailPoint, Training LMS, Notification)"
kubectl apply -f "${K8S}/20-mocks.yaml"

echo "   • BAMOE service"
kubectl apply -f "${K8S}/30-bamoe.yaml"

echo "   • Operator UI"
kubectl apply -f "${K8S}/40-operator-ui.yaml"

echo "   • Ingress routes"
kubectl apply -f "${K8S}/50-ingress.yaml"

echo ""
echo "⏳  Waiting for everything to be ready…"
kubectl -n bamoe-demo wait --for=condition=available --timeout=240s \
  deployment/teleport-adapter deployment/sailpoint-mock deployment/training-lms-mock \
  deployment/notification-mock deployment/bamoe-service deployment/operator-ui || true

echo ""
kubectl -n bamoe-demo get pods

echo ""
echo "✅  Deployment complete."
echo ""
echo "🌐  Demo URLs:"
echo "    Operator UI       →  http://operator.localtest.me"
echo "    SailPoint mock    →  http://sailpoint.localtest.me"
echo "    Teleport (cloud)  →  https://${PROXY}"
echo "    BAMOE API         →  http://bamoe.localtest.me/q/swagger-ui"
echo "    Notifications     →  http://notification.localtest.me/api/notifications"
echo ""
echo "    Next: ./setup/04-seed-demo.sh"
