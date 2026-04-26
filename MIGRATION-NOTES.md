# Migrating to the Teleport Cloud trial tenant

This document walks through replacing the in-cluster Teleport pod with your `yellow-glitter.trial.teleport.sh` Cloud tenant.

## What's changing

| Before | After |
|---|---|
| Teleport runs as a pod in kind | Teleport runs as your Cloud trial tenant |
| Adapter authenticates via in-cluster identity | Adapter authenticates via downloaded identity file |
| `03-deploy.sh` bootstraps Teleport | Bootstrap is a separate step (`02b-bootstrap-tenant.sh`) you run once against the tenant |
| Demo URL: `http://teleport.localtest.me` | Demo URL: `https://yellow-glitter.trial.teleport.sh` |

The architecture is otherwise identical. BAMOE → adapter → Teleport remains the same; only the Teleport endpoint changes.

## One-time prerequisites

```bash
# 1. Install tctl on your laptop (if you don't have it)
# Linux:
curl https://goteleport.com/static/install.sh | bash -s 15.4.0
# macOS:
brew install teleport

# 2. Log into your tenant (you'll be prompted for the admin user + password)
tsh login --proxy=yellow-glitter.trial.teleport.sh

# 3. Verify
tctl status
```

## Files to apply (in order)

### Step 1 — Replace these files with the new versions

| Path in your project | Source |
|---|---|
| `setup/02b-bootstrap-tenant.sh` | NEW file |
| `setup/03-deploy.sh` | replaces existing |
| `teleport/bamoe-bot.yaml` | replaces existing |
| `k8s/15-teleport-adapter.yaml` | replaces existing |
| `k8s/50-ingress.yaml` | replaces existing |
| `services/bamoe-service/src/main/java/com/ibm/bamoe/access/services/WorkflowOrchestrator.java` | replaces existing |

### Step 2 — Delete these files (no longer needed)

```bash
rm k8s/10-teleport.yaml
rm teleport/teleport.yaml
```

### Step 3 — Make the new bootstrap script executable

```bash
chmod +x setup/02b-bootstrap-tenant.sh
chmod +x setup/03-deploy.sh
```

## Run the migrated demo

```bash
# 1. Wipe the kind state from previous attempts
kubectl delete namespace bamoe-demo --ignore-not-found

# 2. Bootstrap the tenant (one-time per tenant)
./setup/02b-bootstrap-tenant.sh

# 3. Rebuild only the BAMOE service (the source changed)
cd services/bamoe-service
docker build -t teleport-demo/bamoe-service:1.0.0 .
kind load docker-image teleport-demo/bamoe-service:1.0.0 --name bamoe-demo
cd ../..

# 4. Deploy
./setup/03-deploy.sh

# 5. Seed
./setup/04-seed-demo.sh
```

## Verification

After step 2, log into `https://yellow-glitter.trial.teleport.sh/web` and check:

- **Access Management → Roles** — you should see `maximo-engineer`, `maximo-planner`, `maximo-supervisor`, `maximo-viewer`, `bamoe-bot`
- **Access Management → Users** — you should see `bamoe-bot`
- **Access Lists** — you should see four `maximo-*` lists with quarterly/monthly review cadences

After step 4, run a sample request via the SailPoint mock and verify in the Cloud UI:

- A new user (`jdoe`, etc.) appears under **Access Management → Users**
- The user is a member of the appropriate Access List

## Demo script changes

In `docs/DEMO-SCRIPT.md`, every reference to `http://teleport.localtest.me` becomes `https://yellow-glitter.trial.teleport.sh`. The narrative is otherwise unchanged — and now stronger, because:

- You're showing **the actual Teleport Cloud product** the panel sells
- **Access Lists work**, so Act 5's recurring review story is back in
- The polished web UI makes the audit log story visually stronger
- `tsh login --proxy=yellow-glitter.trial.teleport.sh` actually goes to a real, polished Teleport endpoint with proper TLS

When you mention production, say: *"This trial tenant is exactly the same product a customer in production uses — same web UI, same audit log, same Access Lists. The only thing that changes for production is rotating credentials with `tbot` instead of the long-lived identity file we generated for the demo."*

## Trial expiration

The 14-day trial clock starts the day you signed up. Make sure your interview is well inside that window. If the demo lands on day 13 or later, request an extension from Teleport — they'll usually grant it for an active interview process.
