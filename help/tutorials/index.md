---
layout: default
title: Tutorials
nav_order: 3
has_children: true
permalink: /tutorials/
---

# Tutorials
{: .no_toc }

Common jobs, step by step. Each tutorial names the permission it needs and the screens it uses.
{: .fs-6 .fw-300 }

| Tutorial | You'll need |
|---|---|
| [Invite a user](invite-a-user/) | `users.manage` |
| [Turn an app on or off for someone](turn-access-on-or-off/) | `entitlements.manage`, or owning the app |
| [Give someone a role](assign-a-role/) | `roles.manage` (and every permission the role grants) |
| [Create an API key](create-an-api-key/) | `api_keys.manage`, or owning the app |
| [Register an Application](register-an-application/) | a verified email address (self-service), or `applications.manage` |
| [Find out who changed something](investigate-with-the-audit-log/) | `audit.view` |

Missing a section or button? Your account doesn't have the permission. See [Roles and permissions](../concepts/roles-and-permissions/).
