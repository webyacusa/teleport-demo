# Demo Presentation Script — Teleport SE Edition (Cloud Trial)

**Audience:** Teleport hiring managers evaluating pre-sales fit.
**Persona you're playing:** A Teleport SE on a discovery + demo call with a mid-sized utility/asset-heavy customer (think Maximo shop) who has an existing enterprise governance stack (SailPoint, an LMS, an internal workflow platform) and an audit finding around privileged access provisioning.
**Time:** 18-22 minutes.

The frame is *not* "look what I built." The frame is "here's how I'd run a real customer call where Teleport is the answer to a specific business problem."

---

## Pre-demo checklist

Run **the morning of the demo** — the bot's identity file expires every ~12 hours on the trial tenant.

```bash
# 1. Regenerate the bot identity file (tenant policy caps these at ~12h)
tsh login --proxy=yellow-glitter.trial.teleport.sh \
          --user=edwin.ortega@ibm.com \
          --out=/tmp/teleport-bot-identity \
          --format=file

# 2. Refresh the Kubernetes Secret and roll the adapter to pick up the new cert
kubectl -n bamoe-demo delete secret teleport-bot-identity
kubectl -n bamoe-demo create secret generic teleport-bot-identity \
  --from-file=identity=/tmp/teleport-bot-identity
kubectl -n bamoe-demo rollout restart deployment/teleport-adapter

# 3. Verify everything is up
kubectl -n bamoe-demo get pods    # all 6 should be Running 1/1

# 4. Confirm tctl talks to the tenant from your laptop
tctl status                        # should show your trial cluster
```

Then open these tabs in your browser, in this order (left → right):

1. `http://sailpoint.localtest.me`                              ← SailPoint mock
2. `http://operator.localtest.me`                               ← Dashboard
3. `http://operator.localtest.me/tasks.html`                    ← Manager inbox
4. **`https://yellow-glitter.trial.teleport.sh/web/users`**     ← Teleport tenant (Users)
5. `http://operator.localtest.me/notifications.html`            ← Notifications
6. A terminal showing `tctl status`                             ← already logged in

**Final check before the call:** trigger one quick request through the SailPoint mock with a non-demo user (or just `psharma` requesting `MAXIMO_VIEWER` — that's a guaranteed training-gap so it doesn't pollute Teleport). Confirm the dashboard updates. Then wipe the dashboard with `kubectl -n bamoe-demo rollout restart deployment/bamoe-service`. You want a clean slate when the panel joins.

---

## Act 1 — Discovery framing (2 min)

> **Don't dive into the demo cold.** Open by anchoring it in a customer scenario.

**Say:**
"Before I show you anything, I want to say that I never do demos without proper discovery, so I am going to walk you through this as if this was a case study that I am presenting to a client that has a similiar issue — a mid-sized organization, on-premise plus AWS, with an audit finding around how access is granted to their core operational system. In this case, that system is IBM Maximo, but the pattern is identical for Snowflake, RDS, EKS, anything Teleport protects.

IBM Maximo is an enterprise asset management (EAM) platform designed to help organizations track, maintain, and optimize their high-value physical assets throughout their entire lifecycle.

The problem they have today: their access provisioning is a 3-to-5-day ticket-driven process. The way it works is that when they are onboarding new employees to be Maximo users, they have to make sure that they complete all the required training. SailPoint approves the request, an admin opens an IT ticket, someone manually checks training compliance, the manager gets emailed, the admin manually creates a Maximo account, manually assigns groups, and there's no unified audit trail. 

**USE THE DRAW IO IMAGE** 

What we're going to do is show them what it looks like when **Teleport is the access plane** and their existing governance workflow drives it. They keep their SailPoint approval flow. They keep their training compliance rules. They get rid of the ticket queue, they get rid of long-lived passwords, and every access change is in Teleport's audit log.

For this demo, I'm running everything against my own Teleport Cloud trial tenant. Let me show you."


---

## Act 2 — The straight-through case (5 min)

**Show:** Tab 1 (SailPoint mock)

**Say:**
"Imagine I'm the customer's auditor watching this. An employee — Jane Doe — has just had her access request for the Maximo Engineer role approved through SailPoint's normal governance flow. SailPoint fires its approved-event webhook, just like it would in any production deployment."

**Action:** Pick **Jane Doe** + **MAXIMO_ENGINEER**, click **Approve & Send**.

**Say:**
"Now SailPoint is done. From here on, the integration layer takes over."

**Show:** Tab 2 (operator dashboard)

"Within a couple of seconds you can see the request landed. The integration platform — whatever orchestrator the customer already runs for business workflows — does three things automatically. It pulls Jane's training records from the LMS, runs them through a compliance rule, and confirms she's qualified. Notice none of this involves Teleport yet — Teleport doesn't need to know about training rules, that's the customer's GRC concern."

**Show:** Tab 3 (manager tasks)

"Now we hit the only human checkpoint. Jane's manager gets a pre-populated form — employee, role, training already validated. The manager isn't asked to verify training; that's already done. They just confirm the role matches Jane's job."

**Action:** Click the task, click **Approve**.

**Show:** Switch to Tab 4 (Teleport Web UI — Users page).

> **This is the moment to slow down.** This is your "hero shot" for Teleport.

**Say:**
"And here's where Teleport comes in. Watch — refresh."

**Action:** Refresh the Teleport users page. `jdoe` should appear.

"Teleport just provisioned Jane's user account. Now let me show you *how* that happened, because this is where Teleport's design really pays off."

**Show:** Tab 6 (terminal). Run from your laptop:

```bash
tctl get user/jdoe
```

"This is Jane's user resource. Notice what's in here is minimal — identity traits, the baseline `access` role. Her actual Maximo permissions don't come from her user record. They come from her membership in an Access List."

**Show:** In the Teleport Web UI, navigate to **Access Management → Access Lists → maximo-engineers → Members**.

"Here's the `maximo-engineers` Access List. Jane was just added. Notice three things specifically:

**One** — the list has a quarterly review cadence configured. Teleport will automatically prompt the list owner to re-attest these memberships every 90 days. That's exactly what the customer's auditor wanted.

**Two** — the membership has provenance metadata: the request ID from the original SailPoint approval, plus the manager's notes. Every membership has an audit story going all the way back to who approved what, when.

**Three** — and this is the big one for any zero-trust conversation — Jane doesn't have a password to Maximo. She doesn't have a long-lived credential anywhere. When she logs into Teleport, she gets a short-lived certificate that her Maximo session uses. When that cert expires, she re-authenticates. There's no password to phish, no credential to leak, no offboarding gap."

**Show:** Tab 4 → **Activity → Audit Log**.

"And every single thing we just did — user creation, access list membership, the role inheritance — is in Teleport's audit log. Structured, exportable, tamper-evident. The customer's SIEM can ingest this directly. Splunk, Datadog, Panther, whatever they use — Teleport has the integration."

**Show:** Live `tsh login` — back to terminal:

```bash
tsh login --proxy=yellow-glitter.trial.teleport.sh --user=jdoe
```

show `tctl get user/jdoe` instead. The point is showing the user got created with the right grants, not necessarily logging in as her.)

"Once Jane has her credentials, `tsh apps ls` shows her the Maximo app. `tsh db ls` shows her the Maximo database. Unified access, one credential, everything audited."

> **This is the moment Teleport hiring managers will be evaluating most closely.** You've shown: Access Lists, audit log, short-lived certs, the API integration. That's the core product surface.

---

## Act 3 — How the orchestrator talks to Teleport (3 min)

> **The "how does it actually work" beat.** Pre-sales interviewers want to see you can explain integration patterns clearly.

**Show:** Open `services/teleport-adapter/server.js` or just talk through it.

**Say:**
"Quick architecture beat — because this is something customers ask in every Teleport conversation: 'how does our automation talk to Teleport securely?'

The pattern I'm using here is a thin adapter service that wraps `tctl`. The orchestrator calls clean REST endpoints; the adapter translates those into Teleport API calls. It's stateless, easy to security-review, and it's the on-ramp pattern Teleport recommends for customers who already have an internal automation framework.

For this demo, the adapter authenticates using a session-scoped identity file I generated from my admin user with `tsh login --out`. **In production, this gets replaced with Teleport Machine ID** — `tbot` running as a sidecar to the adapter, joining via Kubernetes service-account tokens, with certificates rotating automatically every hour. I deliberately took the shorter path for the trial because `tbot` requires JWKS configuration that isn't worth the effort for a 14-day eval — but the architectural diagram and the threat model don't change. Same adapter, different identity provider underneath.

The other integration pattern worth mentioning: for customers who are heavily GitOps-oriented, Teleport ships a Kubernetes Operator. Define users and Access Lists as Kubernetes Custom Resources, and the operator reconciles them into Teleport. Same outcome, different ergonomics. For a customer whose orchestration platform is *already* Kubernetes-native, that's where I'd lean."

> **Why this matters:** You demonstrated you know multiple Teleport-recommended integration patterns and can articulate when each fits — and you were honest about the demo's tradeoffs. That's exactly what an SE does in front of a customer who asks an awkward question.

---

## Act 4 — The non-straight-through path (3 min)

**Show:** Tab 1 — trigger **Priya Sharma** + **MAXIMO_VIEWER**.

**Say:**
"Real life isn't all happy paths. Let's see what happens when training isn't complete."

**Show:** Tab 2 — Priya's row appears with Training: Failed, everything downstream skipped.

"Notice what *didn't* happen — Teleport was never called. No user was created, no list was modified, no audit noise. Critically, the orchestrator's gating logic is upstream of Teleport, so the audit log on Teleport stays clean of noise. Auditors love that. When they review Teleport's logs, every entry corresponds to an actual access change, not failed attempts."

**Show:** Tab 5 — notification to Priya explaining the gap.

**Show:** Tab 1 — trigger **Marcus Webb** + **MAXIMO_ENGINEER**, then go to Tab 3 and **Reject** with a note.

"Same outcome path — manager judgment said no. Teleport stays untouched. Compare this to today's process: Marcus's request would still have generated a ticket, an admin would have created the account, *then* the manager would have realized it was the wrong role and we'd have to undo everything. Here, we don't create what we don't need."

---

## Act 5 — The 'aha' moments for an auditor (3 min)

> **This is where you sell the platform value, not the demo.**

**Show:** Tab 4 → Activity → Audit Log.

**Say:**
"Let me show you a few things I'd specifically demo to a customer's audit and compliance team, because these are the moments that close deals.

**One — every access change is in here, with structured fields.** I can filter by user, by resource, by time. I can export this. I can stream it to my SIEM. Let me filter on `user.create` events from the last few minutes — there's Jane's provisioning event, with the actor field showing it was the BAMOE bot, not a human admin."

**Show:** Filter the audit log to `user.create` if you have time.

"**Two — Access List reviews.** Teleport will automatically open a review every 90 days for the engineering list, every 30 days for supervisors. The list owner has to log in and explicitly re-attest. If they miss the deadline, members get auto-removed."

**Show:** Tab 4 → Access Lists → maximo-engineers — point at the recurrence cadence in the audit panel.

"**Three — and this is the killer feature for the audit conversation — when Jane ultimately leaves the company or moves teams, removing her from the Access List immediately revokes her certificates' next renewal. Within 8 hours her access is gone, no admin action required.** Compare that to the customer's current state where they're paying for Maximo licenses for ex-employees because removal is a manual ticket too.

**Four — Teleport unifies this across SSH, Kubernetes, databases, web apps, and Windows desktops.** What I just showed you for Maximo? Same API, same Access List, same audit log for every other system the customer has. That's where you go from 'we solved a Maximo problem' to 'we have one access plane for our whole estate.'"

---

## Act 6 — Wrap & next steps (2 min)

**Say:**
"So to recap — what we built for this customer:

- They keep SailPoint as the request entry point
- They keep their existing business workflow engine for compliance and approvals
- They get rid of the IT ticket queue entirely for routine access
- They get **Teleport as their access plane**, which gives them: short-lived credentials, a single source of audit truth, automated access reviews, a unified login experience across their whole infrastructure, and machine-to-machine identity for their automation tooling.

The on-ramp is small — one Teleport cluster, four Access Lists, one adapter service. The expansion conversation is large — every other access tier they protect, every database, every Kubernetes cluster, every Windows server.

If I were running this as a real opportunity, my next steps with the customer would be:
1. A proof-of-value scoped to one access tier — maybe just engineers — with their actual SailPoint instance
2. A workshop with their audit team to walk through the access review cadence
3. A roadmap conversation about Teleport's other protocols once they have the engineer flow live

Happy to dig into any of that."

---

## Anticipated questions from the panel

These are the questions Teleport interviewers will probably ask. Have answers ready.

**"Why not just use Teleport's built-in Access Requests feature?"**
Great question — and for some customers, that's the right answer. Teleport's Access Requests is fantastic for ad-hoc, just-in-time elevation. But this customer has an existing governance investment in SailPoint and their own workflow platform that they're not going to walk away from, and an existing compliance team trained on those tools. The right pre-sales move is to integrate, not displace. Once they're live with the Teleport access plane, the next-quarter conversation is: "by the way, for break-glass scenarios, here's Access Requests."

**"Why didn't you use Machine ID / tbot for the demo?"**
Honest answer: the trial tenant caps `tctl auth sign` TTLs at 12 hours, and setting up `tbot` with the Kubernetes join method requires JWKS configuration of the kind cluster's service account issuer that isn't worth the effort for a 14-day evaluation. For production at this customer, day-one architecture has `tbot` running as a sidecar to the adapter, joining via the Kubernetes join method, with the adapter's certificate rotating every hour automatically. The architectural drawing doesn't change — only the identity provider underneath the adapter does. The fact that I deliberately punted on this for the trial is itself a useful pre-sales signal: we ship a 14-day-trial-friendly path *and* a production-grade path, and customers don't have to commit to the production-grade path before they've decided Teleport is right for them.

**"How do you handle Teleport being unavailable?"**
The orchestrator's retry policy handles transient failures. For sustained outages, the affected requests show as Failed on the operator dashboard immediately, and the orchestrator can route an alert. Teleport Cloud is multi-AZ behind the scenes; for self-hosted production deployments, the recommended architecture is three or more auth servers in HA with Postgres or DynamoDB for the backend. I'd put this in the deployment-architecture conversation at proposal stage.

**"What about the manager approval — could that be in Teleport too?"**
Absolutely. Teleport's Access Requests has approval workflows built in. The reason it's in the orchestrator in this design is because *the customer* wants approvals routed through their existing manager hierarchy and their existing notification stack. If they don't have that requirement, Teleport's native approval flow is a one-line config change.

**"What's the licensing implication?"**
For this customer scope — let's say 500 internal users plus the bot identity for the adapter — they'd need Teleport Enterprise to get Access Lists with reviews and the audit features I showed. The trial I'm running this on right now *is* Enterprise — same product, just time-boxed. Cloud or self-hosted both work; for a financial services customer with data residency concerns I'd lean self-hosted; for the typical mid-market customer, Teleport Cloud is the easier on-ramp.

**"Why an adapter and not direct Teleport calls from the orchestrator?"**
Three reasons. (1) Keeps the Teleport-specific auth concerns — Machine ID, certificate rotation — out of the orchestrator. (2) Lets the customer security-review one small surface independently. (3) Lets them swap orchestrators later without touching the Teleport integration. Same architectural reasoning as putting any third-party integration behind a facade.

**"Is that a trial tenant URL?"**
Yes — `*.trial.teleport.sh` is a 14-day Teleport Cloud trial. I deliberately built the demo on a trial because that's exactly what a customer in evaluation experiences on day one. Same web UI, same Access Lists, same audit log as paid Cloud. The only thing that's different is the time horizon.

**"How would you size this for a 10K-user enterprise?"**
Teleport's published reference architecture handles this comfortably with three auth nodes, a Postgres or DynamoDB backend, and S3 for session recordings. The adapter scales horizontally; it's stateless. The orchestrator side is the customer's existing capacity. I'd want to see their actual provisioning volume before sizing the auth tier — is this 50 changes a day or 5,000? — but it's not the bottleneck in this architecture.

---

## What you should *not* do

- **Don't apologize for the orchestrator.** It's the integration layer, full stop. Treat it the way a Salesforce SE treats whatever ESB the customer happens to use.
- **Don't over-explain what Teleport is.** The interviewers know. Use product names without defining them. "Access Lists," "Machine ID," "tbot," "audit log" — speak Teleport.
- **Don't get pulled into a deep-dive on the orchestrator's internals.** If asked, deflect: "the orchestrator is whatever the customer already runs — what matters is the integration contract with Teleport, which is consistent regardless."
- **Don't wing the live `tsh login`.** If your network is iffy or you haven't pre-set Jane's password, skip it — show `tctl get user/jdoe` instead. The proof is that the user exists and is in the right Access List.
- **Don't forget to regenerate the bot identity file before the demo.** It expires every ~12 hours. Run the four commands at the top of this script ~30 minutes before the call.
- **Don't try to navigate Teleport's UI cold.** Click through the Users → Access Lists → Audit Log path *before* the demo so muscle memory is there. The Teleport UI is intuitive but a fumbling presenter looks worse than a fumbling product.
