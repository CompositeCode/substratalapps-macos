---
layout: default
title: Find out who changed something
parent: Tutorials
nav_order: 6
permalink: /tutorials/investigate-with-the-audit-log/
screens: [AUD-01, AUD-02, USR-03]
---

# Find out who changed something
{: .no_toc }

Every change on the platform is recorded in the audit log: who did it, to what, and when.
{: .fs-6 .fw-300 }

{% include availability.html %}

**You'll need:** `audit.view` (the `superadmin`, `support` and `billing_admin` roles have it).

1. Under **Administration**, choose **Audit Log** (⌥⌘4).
2. Narrow it down with the filters:
   - **Actor:** a person, an API key, or the system (scheduled jobs).
   - **Action:** for example `entitlement.disabled` or `api_key.revoked`.
   - **Target:** the user, app, organization or key that was changed.
   - **Time range.**
3. Select an event. The inspector (⌥⌘I) shows the before and after values.

## Common questions

| Question | Filter |
|---|---|
| Who turned off Dana's access? | Target = Dana's user, action `entitlement.disabled` |
| What did this API key do? | Actor = the key |
| What have I changed today? | Actor = you, time range today |
| What happened to this app? | App = the app |

To see one person's history, open them in **Users** and choose the **Activity** tab.

## Limits

- The log covers the last year. Older events are archived and available through support. A banner tells you when your search reaches the start of what's available.
- Events can't be edited or deleted by anyone.
- To keep a copy, export the range you're looking at (staff with `audit.view`).

{: .macos }
Drag an event out of the list to save it as a `.json` file.
