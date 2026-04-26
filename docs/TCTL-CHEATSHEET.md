# `tctl` Cheat Sheet — for use during the demo

Quick commands to have ready while presenting. All run from your laptop terminal once you've port-forwarded or via `kubectl exec`.

## Setup once

```bash
# Easiest — exec into the Teleport pod
alias tctl='kubectl -n bamoe-demo exec -i deploy/teleport -- tctl'
```

## "Show me the user that just got provisioned"

```bash
tctl get user/jdoe
```

What this shows the audience: the user record is *minimal* — just the baseline `access` role and identity traits. Permissions live elsewhere.

## "Show me the access list and its members"

```bash
tctl get access_list/maximo-engineers
tctl get access_list_member --access-list=maximo-engineers
```

What this shows: who's in the list, when they were added, by whom, with what reason. **Notice the audit/recurrence block** — point at it.

## "Show me the audit log for the last few minutes"

```bash
tctl events ls --types=user.create,access_list.member.create --limit=10
```

What this shows: structured audit entries — every user creation and access list change, with timestamps, actors, and request IDs. **This is the SIEM-ready audit feed.**

## "What roles are configured?"

```bash
tctl get roles --format=text
```

Use this to walk through the role definitions — which databases each role can access, MFA requirements for supervisors, etc.

## "Trigger an access review for the supervisors list right now"

```bash
tctl access-list review create --access-list=maximo-supervisors \
  --reviewer=admin --next-review-date="$(date -u -d '+30 days' +%Y-%m-%dT%H:%M:%SZ)"
```

(Optional flex move — shows you know the review API. Skip if running short on time.)

## "Log in as the user we just provisioned"

```bash
# Local laptop, not in the cluster
tsh login --proxy=teleport.localtest.me --user=jdoe --insecure
tsh status
tsh apps ls
tsh db ls
```

`--insecure` is needed only because the demo cluster uses self-signed TLS. **Never use `--insecure` in front of a real customer.** Have a real cert if you can swing it; otherwise, just demo `tsh status` after a successful login.

## "Reset the admin password" (if you lock yourself out)

```bash
kubectl -n bamoe-demo exec deploy/teleport -- tctl users reset admin
```

Prints a one-time signup URL.

## "Reset the demo to a clean state"

```bash
# Remove the test members
for name in jdoe mwebb psharma lortega akhan; do
  tctl rm access_list_member/maximo-engineers/$name 2>/dev/null || true
  tctl rm access_list_member/maximo-planners/$name 2>/dev/null || true
  tctl rm access_list_member/maximo-supervisors/$name 2>/dev/null || true
  tctl rm access_list_member/maximo-viewers/$name 2>/dev/null || true
  tctl rm user/$name 2>/dev/null || true
done

# Restart BAMOE to clear in-memory state
kubectl -n bamoe-demo rollout restart deployment/bamoe-service
```
