#!/usr/bin/env bash
# Resets demo state between rehearsals.
#
# What this DOES:
#   - Deletes the seed users from Teleport (jdoe, mwebb, psharma, lortega, akhan)
#   - Removes them from any Maximo Access Lists they joined
#   - Wipes BAMOE's in-memory request dashboard
#
# What this does NOT do:
#   - Touch your bootstrap resources (roles, access lists themselves, bot user)
#   - Reset the bot identity file (run the morning-of cert-rotation if needed)
#   - Modify your admin user
#
# Run this at the START of every rehearsal AND immediately before the panel demo.

set -euo pipefail

PROXY="${TELEPORT_PROXY:-yellow-glitter.trial.teleport.sh}"
SEED_USERS=(jdoe mwebb psharma lortega akhan)
ACCESS_LISTS=(maximo-engineers maximo-planners maximo-supervisors maximo-viewers)

echo "🧹  Resetting demo state…"
echo ""

# ── Sanity checks ────────────────────────────────────────────────────────────
if ! command -v tctl >/dev/null; then
  echo "❌  tctl not found on this host."
  exit 1
fi
if ! tsh status >/dev/null 2>&1; then
  echo "❌  Not logged in. Run:  tsh login --proxy=${PROXY} --user=<your-admin-email>"
  exit 1
fi

# ── Remove access list memberships ───────────────────────────────────────────
echo "📝  Removing seed users from Access Lists…"
for list in "${ACCESS_LISTS[@]}"; do
  for u in "${SEED_USERS[@]}"; do
    if tctl acl users rm "${list}" "${u}" 2>/dev/null; then
      echo "   ✓ removed ${u} from ${list}"
    fi
  done
done
echo ""

# ── Delete users ─────────────────────────────────────────────────────────────
echo "👤  Deleting seed users from Teleport…"
for u in "${SEED_USERS[@]}"; do
  if tctl rm "user/${u}" 2>/dev/null; then
    echo "   ✓ deleted user ${u}"
  fi
done
echo ""

# ── Reset BAMOE in-memory dashboard ──────────────────────────────────────────
echo "📊  Wiping BAMOE dashboard state (rolling restart)…"
if kubectl -n bamoe-demo get deployment/bamoe-service >/dev/null 2>&1; then
  kubectl -n bamoe-demo rollout restart deployment/bamoe-service >/dev/null
  kubectl -n bamoe-demo rollout status deployment/bamoe-service --timeout=60s >/dev/null
  echo "   ✓ bamoe-service restarted"
else
  echo "   ⚠  bamoe-service deployment not found — is the cluster up?"
fi
echo ""

# ── Verify cleanup ───────────────────────────────────────────────────────────
echo "🔍  Verifying clean state…"
LEFTOVER_USERS=$(tctl get users --format=text 2>/dev/null \
  | awk 'NR>1 {print $1}' \
  | grep -E "^($(IFS='|'; echo "${SEED_USERS[*]}"))$" || true)

if [ -z "${LEFTOVER_USERS}" ]; then
  echo "   ✓ no seed users remain in tenant"
else
  echo "   ⚠  these users still exist (manual cleanup may be needed):"
  echo "${LEFTOVER_USERS}" | sed 's/^/     /'
fi

echo ""
echo "✅  Demo state reset."
echo ""
echo "    Tenant:    https://${PROXY}/web"
echo "    Dashboard: http://operator.localtest.me"
echo ""
echo "    Ready for rehearsal."
