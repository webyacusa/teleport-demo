# Dev Environment Setup

This document walks through setting up everything you need to run the demo on your laptop.

## Prerequisites

Install these once:

| Tool | Version | Install |
|---|---|---|
| **Docker** (or Podman) | latest | https://docs.docker.com/get-docker/ |
| **kind** | ≥ 0.22 | `brew install kind` · `go install sigs.k8s.io/kind@latest` · [docs](https://kind.sigs.k8s.io/docs/user/quick-start/) |
| **kubectl** | ≥ 1.28 | `brew install kubectl` |
| **Java** | 17 (Temurin) | `brew install temurin@17` or sdkman |
| **Maven** | ≥ 3.8 | `brew install maven` |
| **curl & jq** | — | usually preinstalled; jq: `brew install jq` |

**On Linux:** ensure Docker daemon is running (`systemctl start docker`) and that your user is in the `docker` group.

**On Mac (Apple Silicon):** Docker Desktop handles multi-arch automatically. Allocate at least 4 CPU / 6 GB RAM in Docker's Resources settings.

**On Windows:** use WSL2 with Docker Desktop. Run all scripts from inside a WSL distro (Ubuntu recommended).

## Verify prerequisites

```bash
docker version     # Server running
kind version       # 0.22+
kubectl version --client
java -version      # 17.x
mvn -v
```

## Network note — localtest.me

The demo uses hostnames like `operator.localtest.me`. This is a public DNS trick — `*.localtest.me` always resolves to `127.0.0.1`. You don't need to edit `/etc/hosts`. If your corporate network blocks this, add these lines to `/etc/hosts` instead:

```
127.0.0.1   operator.localtest.me teleport.localtest.me bamoe.localtest.me
127.0.0.1   sailpoint.localtest.me training.localtest.me notification.localtest.me
```

## Run the demo

From the project root:

```bash
./setup/01-setup-kind.sh      # ~2 minutes — creates cluster + ingress
./setup/02-build-images.sh    # ~5-8 minutes first run — Maven downloads + Docker builds
./setup/03-deploy.sh          # ~2 minutes — waits for Teleport + BAMOE readiness
./setup/04-seed-demo.sh       # ~30 seconds — fires a few sample requests
```

When all four scripts complete, open:

- **http://operator.localtest.me** — KPI dashboard and task inbox
- **http://sailpoint.localtest.me** — Trigger new approvals
- **http://teleport.localtest.me** — See created users/groups (login `admin` / `admin`)

## Running BAMOE in dev mode (hot reload)

For active BPMN/DMN/Java changes, run the BAMOE service outside the cluster with live reload:

```bash
cd services/bamoe-service

# Point at cluster services via kubectl port-forwards
kubectl -n bamoe-demo port-forward svc/teleport-adapter 3500:3500 &
kubectl -n bamoe-demo port-forward svc/training-lms-mock 3001:3001 &
kubectl -n bamoe-demo port-forward svc/notification-mock 3003:3003 &

mvn quarkus:dev \
  -Dteleport.adapter.url=http://localhost:3500 \
  -Dquarkus.rest-client.training-lms.url=http://localhost:3001 \
  -Dquarkus.rest-client.notification.url=http://localhost:3003
```

This gives you:
- **BPMN hot-reload**: edit `accessProvisioning.bpmn` → save → Quarkus recompiles
- **DMN hot-reload**: edit `trainingCompliance.dmn` → save → same
- **Swagger UI**: http://localhost:8080/q/swagger-ui
- **Kogito management**: http://localhost:8080/q/dev

Point your SailPoint mock at your dev BAMOE with:
```bash
kubectl -n bamoe-demo set env deployment/sailpoint-mock BAMOE_URL=http://host.docker.internal:8080
```

## Troubleshooting

**"BAMOE pod not ready / stuck in CrashLoopBackOff"**
Check logs: `kubectl -n bamoe-demo logs -l app=bamoe-service --tail=100`.
The most common issue is the Teleport adapter failing on startup because the identity file isn't ready yet (the deploy script generates it after Teleport boots). BAMOE's readiness probe should handle this but if the pod gives up, delete it (`kubectl -n bamoe-demo delete pod -l app=bamoe-service`) and it'll restart.

**"Teleport takes forever to start"**
First boot imports the realm and builds the admin console — this is slow (~60s on M1, longer on x86). It's a one-time cost.

**"Images not found when deploying"**
Run `docker images | grep bamoe-demo` — you should see 5 images. If any are missing, rerun `./setup/02-build-images.sh`. If they exist but kind can't see them, rerun just the `kind load docker-image` step manually.

**"Ingress returns 404"**
Ingress controller needs ~60s to start after `01-setup-kind.sh`. If still 404 after that: `kubectl -n ingress-nginx get pods` — controller should be `Running`.

**"Manager task never appears in UI"**
Check the process is actually ACTIVE not ERROR: `curl http://bamoe.localtest.me/accessProvisioning/management/processes/accessProvisioning/instances | jq`. If status is ERROR, inspect BAMOE logs for the failure cause.

**"I need to rebuild the BAMOE image after changes"**
```bash
cd services/bamoe-service && docker build -t bamoe-demo/bamoe-service:1.0.0 .
kind load docker-image bamoe-demo/bamoe-service:1.0.0 --name bamoe-demo
kubectl -n bamoe-demo rollout restart deployment/bamoe-service
```

## Teardown

```bash
./setup/cleanup.sh   # deletes the kind cluster entirely
```
