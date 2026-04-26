#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
K8S="${ROOT}/k8s"

echo "🚀  Applying Kubernetes manifests…"

echo "   • namespace"
kubectl apply -f "${K8S}/00-namespace.yaml"

echo "   • Teleport ConfigMap (built from teleport/teleport.yaml)"
kubectl -n bamoe-demo delete configmap teleport-config --ignore-not-found
kubectl -n bamoe-demo create configmap teleport-config \
  --from-file=teleport.yaml="${ROOT}/teleport/teleport.yaml"

echo "   • Teleport (skipping placeholder ConfigMap from manifest)"
# Skip the first YAML document (the placeholder ConfigMap we already created
# from a real file above). We do this by counting `---` separators and only
# emitting lines once we've seen the second one (= start of doc #2).
awk '/^---$/{c++} c>=2 {print}' "${K8S}/10-teleport.yaml" | kubectl apply -f -

echo "⏳  Waiting for Teleport to come up (~60-90s)…"
kubectl -n bamoe-demo rollout status deployment/teleport --timeout=240s

echo "🔧  Bootstrapping Teleport — admin user, roles, access lists, bot identity"

# Wait until tctl works inside the pod
for i in $(seq 1 30); do
  if kubectl -n bamoe-demo exec deploy/teleport -- tctl status >/dev/null 2>&1; then break; fi
  echo "   …auth not ready yet ($i/30)"; sleep 4
done

echo "   • creating admin user"
kubectl -n bamoe-demo exec deploy/teleport -- tctl users add admin \
  --roles=editor,access,auditor --logins=admin 2>/dev/null || true

echo "   • applying roles.yaml"
kubectl -n bamoe-demo exec -i deploy/teleport -- tctl create -f --force < "${ROOT}/teleport/roles.yaml"

echo "   • applying bamoe-bot.yaml"
kubectl -n bamoe-demo exec -i deploy/teleport -- tctl create -f --force < "${ROOT}/teleport/bamoe-bot.yaml" || true

echo "   • applying access-lists.yaml"
kubectl -n bamoe-demo exec -i deploy/teleport -- tctl create -f --force < "${ROOT}/teleport/access-lists.yaml" || true

echo "   • generating identity file for the adapter"
kubectl -n bamoe-demo exec deploy/teleport -- tctl auth sign \
  --user=admin --out=/tmp/identity --ttl=720h --format=file >/dev/null

# Pull it out of the pod via cat (more reliable than `kubectl cp` across versions)
kubectl -n bamoe-demo exec deploy/teleport -- cat /tmp/identity > /tmp/teleport-identity

echo "   • storing identity file as Kubernetes Secret"
kubectl -n bamoe-demo delete secret teleport-bot-identity --ignore-not-found
kubectl -n bamoe-demo create secret generic teleport-bot-identity \
  --from-file=identity=/tmp/teleport-identity
rm -f /tmp/teleport-identity

echo ""
echo "📦  Deploying Teleport adapter, mocks, BAMOE, UI…"
# Same trick — skip the placeholder Secret in 15-teleport-adapter.yaml since
# we just created the real one above.
awk '/^---$/{c++} c>=2 {print}' "${K8S}/15-teleport-adapter.yaml" | kubectl apply -f -

kubectl apply -f "${K8S}/20-mocks.yaml"
kubectl apply -f "${K8S}/30-bamoe.yaml"
kubectl apply -f "${K8S}/40-operator-ui.yaml"
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
echo "    Teleport Web UI   →  http://teleport.localtest.me"
echo "    BAMOE Swagger     →  http://bamoe.localtest.me/q/swagger-ui"
echo "    Notifications     →  http://notification.localtest.me/api/notifications"
echo ""
echo "🔑  Teleport admin signup link (open this once to set admin password):"
kubectl -n bamoe-demo exec deploy/teleport -- tctl users reset admin 2>/dev/null \
  | grep -E '^https?://' || \
  echo "   Run:  kubectl -n bamoe-demo exec deploy/teleport -- tctl users reset admin"
echo ""
echo "   Next: ./setup/04-seed-demo.sh"
