# Architecture

## Component map

```
SailPoint (mock) ─── webhook ───▶ BAMOE ──┬──▶ Training LMS (mock)
                                          │
                                          │     ┌─────────────────┐
                                          ├────▶│ Teleport        │
                                          │     │ Adapter         │
                                          │     │ (tctl wrapper)  │
                                          │     └────────┬────────┘
                                          │              │  uses identity file
                                          │              ▼
                                          │     ┌─────────────────┐
                                          │     │ ★ Teleport ★    │
                                          │     │ Auth + Proxy    │
                                          │     │ + Audit Log     │
                                          │     └─────────────────┘
                                          │
                                          └──▶ Notification (mock)
```

## Process flow (BPMN)

```
Start  ──▶  Audit  ──▶  Fetch Training  ──▶  Validate (DMN)
                                                  │
                                          ┌───────┴───────┐
                                          │ qualified?    │
                                       Yes│              │No
                                          ▼              ▼
                                   Manager Task     Notify Failure ──▶ End (Training Gap)
                                          │
                                  ┌───────┴───────┐
                                  │ approved?     │
                               Yes│              │No
                                  ▼              ▼
                       Create Teleport User    End (Rejected)
                                  │
                                  ▼
                        Add to Access List
                                  │
                                  ▼
                          Notify Success
                                  │
                                  ▼
                          End (Provisioned)
```

## Teleport resource model

This is the part Teleport pre-sales conversations zero in on. Three resources matter:

### Roles (`kind: role`)

Define **what permissions look like** — node labels, kubernetes_groups, db_users, app_labels, etc. Roles are reusable templates. Four are pre-defined here:

| Role | Permissions snapshot | TTL | MFA |
|---|---|---|---|
| `maximo-engineer`   | env=maximo nodes/dbs, kubernetes_groups=[maximo-engineers], db_users=[maximo_engineer] | 8h | no |
| `maximo-planner`    | role=planning nodes only, db_users=[maximo_planner] | 8h | no |
| `maximo-supervisor` | env=maximo all nodes, kubernetes_groups=[supervisors, engineers] | 8h | **yes** |
| `maximo-viewer`     | apps only, no SSH, db_users=[maximo_viewer] | 4h | no |

Note the supervisor role requires `require_session_mfa: true` — auditors love this.

### Access Lists (`kind: access_list`)

A managed group of users who all get the same Role grants. **This is the thing BAMOE adds members to.** Access Lists carry the audit cadence — quarterly review for engineers/planners/viewers, monthly for the elevated supervisor list. When the cadence elapses, owners are auto-prompted to re-attest.

### Bot identity (`kind: bot`)

The Teleport-recommended pattern for service-to-service authentication. The adapter holds a bot identity (this demo uses a long-lived identity file for simplicity; production replaces it with `tbot` rotating certificates every hour). The bot has narrow rules — only `user`, `access_list`, `access_list_member` write — so a compromised adapter can't escalate.

## Integration patterns (the customer conversation)

Two ways a customer can integrate their orchestrator with Teleport:

### Pattern A — Thin REST adapter (this demo)

```
BAMOE  ── HTTP ──▶  Adapter  ── tctl ──▶  Teleport
```

**Pros:** Easy to security-review (one small surface). Orchestrator stays Teleport-agnostic. Familiar to customers who already wrap third-party services. Works with any orchestrator that can make HTTP calls.

**Cons:** Two services to operate. Adapter's identity needs care (Machine ID/`tbot`).

**When to recommend:** Customer's orchestration platform doesn't already have Kubernetes-native integration. Customer wants a thin abstraction layer for security review.

### Pattern B — Teleport Kubernetes Operator

```
BAMOE  ── kubectl apply ──▶  K8s API  ──▶  Teleport Operator  ──▶  Teleport
```

The operator watches Custom Resources like `TeleportUser` and `TeleportAccessList` and reconciles them into Teleport.

**Pros:** GitOps-native. Declarative. Standard kubectl/Argo/Flux tooling. No bespoke service to maintain.

**Cons:** Requires Kubernetes for the orchestrator side. Less flexible for non-CRD workflows.

**When to recommend:** Customer is already heavily Kubernetes-oriented and uses GitOps. Audit teams familiar with Kubernetes-native tooling.

## DMN compliance rules

The `trainingCompliance.dmn` decision table:

| Role | Required modules |
|---|---|
| Engineer   | SAFETY-101 + ASSET-201 |
| Planner    | SAFETY-101 + PLANNER-301 |
| Supervisor | SAFETY-101 + SAFETY-201 + SUPERVISOR-401 |
| Viewer     | SAFETY-101 |
| *anything else* | **Not qualified** |

Edit the DMN; in dev mode (`mvn quarkus:dev`) it hot-reloads.

## Training data seed (LMS mock)

| User | Modules | Qualified for |
|---|---|---|
| `jdoe`     | SAFETY-101, ASSET-201, PLANNER-301           | Engineer, Planner, Viewer |
| `mwebb`    | SAFETY-101, ASSET-201                        | Engineer, Viewer |
| `psharma`  | *(none)*                                     | Nothing |
| `lortega`  | SAFETY-101, SAFETY-201, SUPERVISOR-401, ASSET-201 | Supervisor, Engineer, Viewer |
| `akhan`    | SAFETY-101                                   | Viewer |

## Security model in this demo (vs. production)

| Concern | Demo | Production |
|---|---|---|
| Adapter identity | Long-lived admin identity file in K8s Secret | `tbot`-managed, 1-hour rotating certs |
| BAMOE → Adapter auth | None | mTLS or signed-webhook |
| SailPoint → BAMOE auth | None | HMAC signature on the webhook payload |
| Operator UI auth | None | Teleport-issued OIDC session |
| MFA | Disabled at cluster level | `second_factor: webauthn` (required) |
| TLS | HTTP throughout | TLS terminated at Teleport proxy with real ACME or PKI certs |

Each of those is a "for the proposal stage" conversation, not a "first-day demo" one.

## Observability

- **Teleport Web UI** — `http://teleport.localtest.me` — Users, Access Lists, audit log
- **BAMOE Swagger** — `http://bamoe.localtest.me/q/swagger-ui` — REST endpoints
- **Kogito dev console** — `http://bamoe.localtest.me/q/dev` — live BPMN viewer, running instances, DMN tester
- **`tctl` from the Teleport pod** — `kubectl -n bamoe-demo exec deploy/teleport -- tctl <command>`

## What's real vs. mocked

| Component | Status |
|---|---|
| **Teleport** | **Real** — actual Teleport 15.4.0 cluster |
| **Teleport Adapter** | **Real** — actual `tctl` calls against the cluster |
| BAMOE (Kogito + Quarkus) | Real — actual BPMN execution, actual DMN evaluation |
| SailPoint | Mock — Node.js webhook trigger |
| Training LMS | Mock — Node.js with realistic dataset |
| Maximo | Not in demo — represented by Teleport's role/Access List grants. In a real customer deployment Teleport would proxy SSH/database/app access to Maximo using these grants. |
| Notifications | Mock — captures in memory |
