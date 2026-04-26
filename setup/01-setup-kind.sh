#!/usr/bin/env bash
set -euo pipefail

CLUSTER=${CLUSTER:-bamoe-demo}

echo "🔧  Checking prerequisites…"
for tool in docker kind kubectl; do
  command -v "$tool" >/dev/null || { echo "❌  Missing: $tool"; exit 1; }
done
echo "   ✓ docker, kind, kubectl present"

if kind get clusters | grep -q "^${CLUSTER}$"; then
  echo "ℹ️   Cluster '${CLUSTER}' already exists — skipping creation"
else
  echo "🔧  Creating kind cluster '${CLUSTER}' with ingress ports exposed…"
  cat <<EOF | kind create cluster --name "${CLUSTER}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - { containerPort: 80,  hostPort: 80,  protocol: TCP }
      - { containerPort: 443, hostPort: 443, protocol: TCP }
EOF
fi

echo "🔧  Installing nginx ingress controller…"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/kind/deploy.yaml

echo "⏳  Waiting for ingress controller to be ready (may take ~60s)…"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo ""
echo "✅  Cluster ready."
echo "   Next: ./setup/02-build-images.sh"
