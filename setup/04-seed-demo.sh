#!/usr/bin/env bash
set -euo pipefail

echo "🌱  Seeding demo data…"

# Wait a bit for everything to truly be reachable
sleep 3

SAILPOINT=http://sailpoint.localtest.me

check_reachable() {
  for i in $(seq 1 20); do
    if curl -s -o /dev/null -w "%{http_code}" "${SAILPOINT}/api/employees" | grep -q "200"; then
      return 0
    fi
    echo "   …still waiting for ingress ($i/20)"
    sleep 3
  done
  echo "❌  Services not reachable at ${SAILPOINT} — check 'kubectl -n bamoe-demo get pods'"
  exit 1
}

echo "⏳  Verifying ingress is routing…"
check_reachable
echo "   ✓ ingress is up"

trigger() {
  local userId=$1
  local role=$2
  echo "   → triggering: ${userId} requests ${role}"
  curl -s -X POST "${SAILPOINT}/api/trigger-approval" \
    -H "Content-Type: application/json" \
    -d "{\"userId\":\"${userId}\",\"role\":\"${role}\"}" | head -c 300
  echo ""
}

# Straight-through case — jdoe has full training for Engineer
trigger "jdoe" "MAXIMO_ENGINEER"
sleep 2

# Half-qualified — mwebb has only Engineer training, tries for Planner → should fail training
trigger "mwebb" "MAXIMO_PLANNER"
sleep 2

# No training at all — psharma tries Viewer → should fail
trigger "psharma" "MAXIMO_VIEWER"
sleep 2

# Fully qualified Supervisor
trigger "lortega" "MAXIMO_SUPERVISOR"

echo ""
echo "✅  Seed requests dispatched."
echo "   Open  http://operator.localtest.me  to see them on the dashboard."
echo "   For approved ones, complete the manager task at  http://operator.localtest.me/tasks.html"
