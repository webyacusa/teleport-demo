# Demo Presentation Script — Teleport SE Edition

**Audience:** Teleport hiring managers evaluating pre-sales fit.
**Persona you're playing:** A Teleport SE on a discovery + demo call with a mid-sized utility/asset-heavy customer (think Maximo shop) who has an existing enterprise governance stack (SailPoint, BAMOE, an LMS) and an audit finding around privileged access provisioning.
**Time:** 18-22 minutes.

The frame is *not* "look what I built." The frame is "here's how I'd run a real customer call where Teleport is the answer to a specific business problem."

---

## Pre-demo checklist

- [ ] Cluster up: `kubectl -n bamoe-demo get pods` — all `Running`
- [ ] Six tabs open, in this order:
  1. `http://sailpoint.localtest.me`
  2. `http://operator.localtest.me`
  3. `http://operator.localtest.me/tasks.html`
  4. **`http://teleport.localtest.me`** ← the Teleport Web UI, logged in as admin
  5. `http://operator.localtest.me/notifications.html`
  6. A terminal showing `kubectl -n bamoe-demo exec deploy/teleport -- tctl status`
- [ ] Have `tsh` installed locally so you can do a live `tsh login` at the end
- [ ] Run `./setup/04-seed-demo.sh` if you want a populated dashboard, or start clean

---

## Act 1 — Discovery framing (2 min)

> **Don't dive into the demo cold.** Open by anchoring it in a customer scenario.

**Say:**
"Before I show you anything, let me set the scene. I want to walk you through how I'd approach a customer demo for someone in our typical buying motion — a mid-sized organization, on-premise plus AWS, with an audit finding around how access is granted to their core operational system. In this case, that system is IBM Maximo, but the pattern is identical for Snowflake, RDS, EKS, anything Teleport protects.

The problem they have today: their access provisioning is a 3-to-5-day ticket-driven process. SailPoint approves the request, an admin opens an IT ticket, someone manually checks training compliance, the manager gets emailed, the admin manually creates a Maximo account, manually assigns groups, and there's no unified audit trail. Their auditor flagged it as a SOX/SOC2 weakness.

What we're going to do is show them what it looks like when **Teleport is the access plane** and their existing governance workflow drives it. They keep their SailPoint approval flow. They keep their training compliance rules. They get rid of the ticket queue, they get rid of long-lived passwords, and every access change is in Teleport's audit log.

Let me show you."

> **Why this opening matters:** Pre-sales interviewers are listening for whether you lead with the *customer's problem*, not the product. You did.

---

## Act 2 — The straight-through case (5 min)

**Show:** Tab 1 (SailPoint mock)

**Say:**
"Imagine I'm the customer's auditor watching this. An employee — Jane Doe — has just had her access request for the Maximo Engineer role approved through SailPoint's normal governance flow. SailPoint fires its approved-event webhook, just like it would in any production deployment."

**Action:** Pick **Jane Doe** + **MAXIMO_ENGINEER**, click **Approve & Send**.

**Say:**
"Now SailPoint is done. From here on, our integration layer takes over."

**Show:** Tab 2 (operator dashboard)

"Within a couple of seconds you can see the request landed. The integration platform — which in this customer's case is BAMOE because that's their standard for business workflows, but it could be any orchestrator — runs three steps automatically. It pulls Jane's training records from the LMS, runs them through a compliance rule, and confirms she's qualified. Notice none of this involves Teleport yet — Teleport doesn't need to know about training rules, that's the customer's GRC concern."

**Show:** Tab 3 (manager tasks)

"Now we hit the only human checkpoint. Jane's manager gets a pre-populated form — employee, role, training already validated. The manager isn't asked to verify training; that's already done. They just confirm the role matches Jane's job."

**Action:** Click the task, click **Approve**.

**Show:** Switch to Tab 4 (Teleport Web UI) — go to **Users**.

> **This is the moment to slow down.** This is your "hero shot" for Teleport.

**Say:**
"And here's where Teleport comes in. Watch — refresh."

**Action:** Refresh the Teleport users page. `jdoe` should appear.

"Teleport just provisioned Jane's user account. Now let me show you *how* that happened, because this is where Teleport's design really pays off."

**Show:** Tab 6 (terminal). Run:

```bash
kubectl -n bamoe-demo exec deploy/teleport -- tctl get user/jdoe
```

"This is Jane's user resource. Notice she has the baseline `access` role. Her actual Maximo permissions don't come from her user record — they come from her membership in an Access List."

**Show:** In the Teleport Web UI, navigate to **Access Lists** → **maximo-engineers** → **Members**.

"Here's the `maximo-engineers` Access List. Jane was just added. Notice three things specifically:

**One** — the list has a quarterly review cadence configured. Teleport will automatically prompt the list owner to re-attest these memberships every 90 days. That's exactly what the customer's auditor wanted.

**Two** — the list has 'reason' metadata: 'Provisioned via BAMOE workflow REQ-XXXX' plus the manager's notes. Every membership has an audit story.

**Three** — and this is the big one for any zero-trust conversation — Jane doesn't have a password to Maximo. She doesn't have a long-lived credential anywhere. When she logs into Teleport, she gets a short-lived certificate — typically 8 hours — that her Maximo session uses. When that cert expires, she re-authenticates. There's no password to phish, no credential to leak, no offboarding gap."

**Show:** Tab 4 (Teleport) → **Audit Log**.

"And every single thing we just did — user creation, list addition, the role assignment — is in Teleport's audit log. This is structured, exportable, tamper-evident. The customer's SIEM can ingest this directly. Splunk, Datadog, whatever they use — Teleport has the integration."

**Show:** Live — back to terminal:

```bash
tsh login --proxy=teleport.localtest.me --user=jdoe
```

"And now Jane can actually use her access. She just got a short-lived cert. If she runs `tsh apps ls`, she sees Maximo. If she runs `tsh db ls`, she sees the Maximo database. Unified access, one credential, everything audited."

> **This is the moment Teleport hiring managers will be evaluating most closely.** You've shown: Access Lists, audit log, short-lived certs, the API integration. That's the core product surface.

---

## Act 3 — How BAMOE talks to Teleport (3 min)

> **The "how does it actually work" beat.** Pre-sales interviewers want to see you can explain integration patterns clearly.

**Show:** Open `services/teleport-adapter/server.js` in your editor side-by-side with `TeleportService.java`.

**Say:**
"Quick architecture beat — because this is something customers ask in every Teleport conversation: 'how does our automation talk to Teleport securely?'

Two patterns customers can choose from. The simple one — what you just saw — is a thin adapter service that wraps `tctl`. The orchestrator calls clean REST endpoints; the adapter translates those into Teleport API calls. It's stateless, easy to security-review, and it's the on-ramp pattern Teleport recommends for customers who already have an internal automation framework like BAMOE.

The adapter authenticates to Teleport using a Machine ID-issued identity. That's Teleport's `tbot` pattern — short-lived certificates that rotate every hour, automatically. So the adapter itself is following the same zero-trust principles as the human users. There's no static admin token sitting in a Kubernetes Secret; the certificate that the adapter holds expires faster than an attacker could exfiltrate it.

The other pattern is the Teleport Kubernetes Operator — define users and Access Lists as Kubernetes Custom Resources, and the operator reconciles them into Teleport. That's what I'd recommend for customers who are already heavily GitOps-oriented. Same outcome, different ergonomics."

> **Why this matters:** You demonstrated you know **two** Teleport-recommended integration patterns and can articulate when each fits.

---

## Act 4 — The non-straight-through path (3 min)

**Show:** Tab 1 — trigger **Priya Sharma** + **MAXIMO_VIEWER**.

**Say:**
"Real life isn't all happy paths. Let's see what happens when training isn't complete."

**Show:** Tab 2 — Priya's row appears with Training: Failed, everything downstream skipped.

"Notice what *didn't* happen — Teleport was never called. No user was created, no list was modified, no audit noise. Critically, the orchestrator's gating logic is upstream of Teleport, so the audit log on Teleport stays clean of noise. Auditors love that. When they review Teleport's logs, every entry corresponds to an actual access change, not failed attempts."

**Show:** Tab 5 — notification to Priya explaining the gap.

**Show:** Tab 1 — trigger **Marcus Webb** + **MAXIMO_ENGINEER**, then go to Tab 3 and **reject** with a note.

"Same outcome path — manager judgment said no. Teleport stays untouched."

---

## Act 5 — The 'aha' moments for an auditor (3 min)

> **This is where you sell the platform value, not the demo.**

**Show:** Tab 4 (Teleport audit log).

**Say:**
"Let me show you a few things that I'd specifically demo to a customer's audit and compliance team, because these are the moments that close deals.

**One — every access change is in here, with structured fields.** I can filter by user, by resource, by time. I can export this. I can stream it to my SIEM.

**Two — Access List reviews.** Teleport will automatically open a review every 90 days for the engineering list, every 30 days for supervisors. The list owner has to log in and explicitly re-attest. If they miss the deadline, members get auto-removed."

**Show:** Teleport Web UI → Access Lists → set up a review (or just point at the configured cadence).

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
Great question — and for some customers, that's the right answer. Teleport's Access Requests is fantastic for ad-hoc, just-in-time elevation. But this customer has an existing governance investment in SailPoint and BAMOE that they're not going to walk away from, and an existing compliance team trained on those tools. The right pre-sales move is to integrate, not displace. Once they're live with the Teleport access plane, the next-quarter conversation is: "by the way, for break-glass scenarios, here's Access Requests."

**"How do you handle Teleport being unavailable?"**
The orchestrator's retry policy handles transient failures. For sustained outages, the affected requests show as Failed on the operator dashboard immediately, and the SLA timer in the workflow can route an alert. Teleport itself runs as an HA cluster of three or more auth servers in production, which is the architecture I'd recommend at the proposal stage.

**"What about the manager approval — could that be in Teleport too?"**
Absolutely. Teleport's Access Requests has approval workflows built in. The reason it's in BAMOE in this design is because *the customer* wants approvals routed through their existing manager hierarchy and their existing notification stack. If they don't have that, Teleport's native approval flow is a one-line config change.

**"What's the licensing implication?"**
For this customer scope — let's say 500 internal users plus the bot identity for the adapter — they'd need Teleport Enterprise to get Access Lists with reviews and the audit features I showed. Cloud or self-hosted both work; for a financial services customer with data residency concerns I'd lean self-hosted; for the typical mid-market customer, Teleport Cloud is the easier on-ramp.

**"Why an adapter and not direct Teleport calls from BAMOE?"**
Three reasons. (1) Keeps the Teleport-specific auth concerns — Machine ID, certificate rotation — out of the orchestrator. (2) Lets the customer security-review one small surface independently. (3) Lets them swap orchestrators later without touching the Teleport integration. Same architectural reasoning as putting any third-party integration behind a facade.

**"How would you size this for a 10K-user enterprise?"**
Teleport's published reference architecture handles this comfortably with three auth nodes, a Postgres or DynamoDB backend, and S3 for session recordings. The adapter scales horizontally; it's stateless. The orchestrator side is the customer's existing capacity. I'd want to see their actual provisioning volume before sizing the auth tier — is this 50 changes a day or 5,000? — but it's not the bottleneck in this architecture.

---

## What you should *not* do

- **Don't apologize for BAMOE.** It's the integration layer, full stop. Treat it the way a Salesforce SE treats whatever ESB the customer happens to use.
- **Don't over-explain what Teleport is.** The interviewers know. Use product names without defining them. "Access Lists," "Machine ID," "tbot," "audit log" — speak Teleport.
- **Don't get pulled into a deep-dive on the BPMN engine.** If asked, deflect: "the orchestrator is whatever the customer already runs — what matters is the integration contract with Teleport, which is consistent regardless."
- **Don't wing the live `tsh login`.** Test it before the demo. If your network is iffy, have a backup screenshot.
