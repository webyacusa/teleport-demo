#!/usr/bin/env bash
# Bootstraps your Teleport Cloud trial tenant with the demo's roles, bot,
# and access lists. Run this ONCE before deploying the rest of the demo.
#
# Prerequisites:
#   - tctl installed on this laptop  (https://goteleport.com/docs/installation/)
#   - You're logged in:  tsh login --proxy=yellow-glitter.trial.teleport.sh
#   - You have editor + auditor roles in the tenant (the default admin user does)
#
# Outputs:
#   /tmp/teleport-bot-identity   — the bot identity file used by the adapter

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROXY="${TELEPORT_PROXY:-yellow-glitter.trial.teleport.sh}"
IDENTITY_OUT="${IDENTITY_OUT:-/tmp/teleport-bot-identity}"

echo "🔍  Checking that tctl is available and logged in…"
if ! command -v tctl >/dev/null; then
  echo "❌  tctl not found. Install Teleport client tools first:"
  echo "    Linux: curl https://goteleport.com/static/install.sh | bash -s 15.4.0"
  echo "    Mac:   brew install teleport"
  exit 1
fi

if ! tsh status >/dev/null 2>&1; then
  echo "❌  Not logged in. Run:  tsh login --proxy=${PROXY}"
  exit 1
fi

LOGGED_IN_PROXY="$(tsh status 2>&1 | awk '/Profile URL/{print $3}' | sed -e 's|https://||' -e 's|:.*||')"
if [ "${LOGGED_IN_PROXY}" != "${PROXY}" ]; then
  echo "❌  tsh is logged into '${LOGGED_IN_PROXY}', not '${PROXY}'."
  echo "    Run:  tsh logout && tsh login --proxy=${PROXY}"
  exit 1
fi
echo "   ✓ tctl available, logged into ${PROXY}"

echo ""
echo "🔧  Applying Teleport resources to ${PROXY}…"

echo "   • applying roles.yaml"
tctl create -f --force "${ROOT}/teleport/roles.yaml"

echo "   • applying bamoe-bot.yaml"
tctl create -f --force "${ROOT}/teleport/bamoe-bot.yaml"

echo "   • applying access-lists.yaml"
tctl create -f --force "${ROOT}/teleport/access-lists.yaml"

echo ""
echo "🔑  Generating bot identity file for the adapter…"
echo "    (This is what the in-cluster adapter will use to authenticate.)"

# Remove any stale file so tctl doesn't prompt
rm -f "${IDENTITY_OUT}"

tctl auth sign \
  --user=bamoe-bot \
  --out="${IDENTITY_OUT}" \
  --ttl=24h \
  --format=file

if [ ! -s "${IDENTITY_OUT}" ]; then
  echo "❌  Identity file was not created at ${IDENTITY_OUT}"
  exit 1
fi

echo "   ✓ identity file written to ${IDENTITY_OUT}"
echo ""
echo "✅  Tenant bootstrap complete."
echo ""
echo "    Verify in the web UI:"
echo "      ${PROXY}  →  Access Management → Roles    (4 maximo-* roles)"
echo "      ${PROXY}  →  Access Management → Users    (bamoe-bot)"
echo "      ${PROXY}  →  Access Lists                 (4 maximo-* lists)"
echo ""
echo "    Next: ./setup/03-deploy.sh"
