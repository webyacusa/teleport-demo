# Teleport Access Provisioning Demo

End-to-end runnable demo positioning **Teleport** as the access plane for a Maximo customer with existing enterprise governance tooling. Built for a Teleport pre-sales conversation.

> **Pre-sales framing:** The customer already has SailPoint, an LMS, and a business workflow engine. They have an audit finding around how Maximo access is granted. The demo shows how Teleport slots into that existing governance stack as the secure access provisioning layer — without forcing the customer to rip-and-replace their orchestration tooling.

## What's demonstrated

- **Teleport as system of record for access** — Users + Access Lists with role-based grants, recurring access reviews, structured audit log
- **Machine ID-style integration** — Adapter service authenticates to Teleport using a long-lived identity file (representing what would be a `tbot`-rotated certificate in production)
- **Short-lived credentials end-to-end** — `tsh login` after provisioning issues an 8-hour cert; no passwords anywhere
- **Compliance-grade audit** — Every access change visible in Teleport's audit log with structured metadata
- **Access reviews** — Quarterly cadence on engineer/planner lists, monthly on supervisor (elevated) — fully automatic prompts
- **Integration pattern customers can adopt** — Thin adapter wrapping `tctl`, plus an alternative path via the Teleport Kubernetes Operator

## Architecture

```
                    ┌────────────────────────┐
                    │  SailPoint (mock)      │
                    │  Customer's existing   │
                    │  governance entry pt.  │
                    └───────────┬────────────┘
                                │ 1. webhook on approval
                                ▼
┌─────────────────┐    ┌──────────────────────────┐    ┌───────────────────────────┐
│ Training LMS    │◀──▶│  BAMOE Service           │    │  ★ Teleport ★             │
│ (mock)          │ 2. │  (Quarkus + Kogito)      │ 3. │  Auth + Proxy + Audit    │
└─────────────────┘    │                          ├──▶ │                           │
                       │  • BPMN: workflow        │    │  • Users                  │
                       │  • DMN: training rules   │    │  • Access Lists           │
                       │  • Manager approval      │    │  • RBAC roles             │
                       │                          │    │  • Audit log              │
                       └──────────┬───────────────┘    └─────────────┬─────────────┘
                                  │                                  │
                                  │ 4. via REST                      │ tctl + identity file
                                  ▼                                  │
                       ┌──────────────────────────┐                  │
                       │  Teleport Adapter        │──────────────────┘
                       │  (Node.js, wraps tctl)   │
                       └──────────────────────────┘
                                  │
                                  ▼
                       ┌──────────────────────────┐
                       │  Notifications (mock)    │
                       └──────────────────────────┘

                       ┌──────────────────────────┐
                       │  Operator UI             │
                       │  Dashboard + Tasks       │
                       └──────────────────────────┘
```

## Components

| Component | Tech | Purpose |
|---|---|---|
| **★ Teleport ★** | Real `teleport:15.4.0` | The hero. Identity store, RBAC, audit log, certificate authority. |
| **Teleport Adapter** | Node.js + `tctl` | Translates clean REST calls into Teleport API operations. The "thin facade" pattern. |
| **BAMOE Service** | Quarkus + Kogito 9.x | Orchestrates the business workflow. BPMN process + DMN compliance rules. |
| **SailPoint Mock** | Node.js | Fires the access-approved webhook that starts the workflow. |
| **Training LMS Mock** | Node.js | Returns training completion records to drive the DMN. |
| **Notification Mock** | Node.js | Captures outbound notifications for the demo. |
| **Operator UI** | Static HTML/JS | KPI dashboard, manager task inbox, notifications log. |

## Quick start

```bash
./setup/00-prereqs.sh          # checks Docker, kind, kubectl, tsh on your laptop
./setup/01-setup-kind.sh       # cluster + ingress
./setup/02-build-images.sh     # builds 6 container images (Maven + Node run inside Docker)
./setup/03-deploy.sh           # deploys, BOOTSTRAPS Teleport, prints admin signup link
./setup/04-seed-demo.sh        # optional — pre-fires sample requests
```

### What gets installed where

Nothing about BAMOE or Teleport touches your laptop directly. Both run as Kubernetes pods.

| Layer | Component | How it lands |
|---|---|---|
| **Your laptop** | docker, kind, kubectl | You install these (or `00-prereqs.sh` checks them) |
| **Your laptop** | tsh (optional) | Only if you want the live `tsh login` demo |
| **Inside Docker (build time)** | Java 17, Maven, Quarkus, Kogito (= BAMOE runtime) | Pulled by `bamoe-service` Dockerfile during `02-build-images.sh` |
| **Inside Docker (build time)** | tctl, tsh | Copied from official Teleport image into the adapter image |
| **In the kind cluster** | Teleport `15.4.0` | Pulled from `public.ecr.aws/gravitational/teleport` by `03-deploy.sh` |
| **In the kind cluster** | BAMOE service | Image built locally, loaded into kind by `02-build-images.sh` |
| **In the kind cluster** | Teleport roles, Access Lists, bot identity | Bootstrapped via `tctl create -f` from `teleport/*.yaml` by `03-deploy.sh` |

So "installing Teleport" happens automatically when `03-deploy.sh` applies `k8s/10-teleport.yaml` and the kubelet pulls the Teleport container image. "Installing BAMOE" happens when `02-build-images.sh` builds the bamoe-service Dockerfile, which runs `mvn package` inside a Maven container that pulls Kogito from Maven Central.

URLs:
- **Operator UI** — http://operator.localtest.me
- **★ Teleport Web UI** — http://teleport.localtest.me — *the centerpiece during the demo*
- **SailPoint mock** — http://sailpoint.localtest.me
- **BAMOE Swagger** — http://bamoe.localtest.me/q/swagger-ui

## Docs

- **[`docs/DEMO-SCRIPT.md`](docs/DEMO-SCRIPT.md)** — 6-act presentation script written for Teleport pre-sales positioning. **Read this first.**
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — component map, Teleport resource model, integration patterns
- [`docs/DEV-SETUP.md`](docs/DEV-SETUP.md) — local environment setup
