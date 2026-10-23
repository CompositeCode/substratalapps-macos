---
layout: default
title: Roles and permissions
parent: Concepts
nav_order: 2
permalink: /concepts/roles-and-permissions/
---

# Roles and permissions
{: .no_toc }

A permission is one thing a person can do. A role is a named set of permissions. You give people roles, not permissions.
{: .fs-6 .fw-300 }

1. TOC
{: toc }

---

## Two kinds of role

- **Platform roles** govern the Hub itself: who can manage users, keys, the audit log, and so on. Staff hold these.
- **App roles** are defined by each app (for example `admin`, `editor`, `viewer` in TimeTrack) and grant only that app's permissions, named `app.<slug>.<action>`.

The two never mix: a platform role never grants anything inside an app, and an app role never unlocks a Hub screen.

## Built-in platform roles

| Role | For | Can't be edited |
|---|---|---|
| `superadmin` | The platform owner. Everything. | ✓ |
| `support` | Helping users: see users, turn access on/off, read the audit log, tenants, billing | ✓ |
| `billing_admin` | Billing: subscriptions, refunds, the audit log, the user list | ✓ |
| `member` | Every account. Nothing beyond your own account. | ✓ |

You can create more platform roles with any mix of the permissions below, but only with permissions you hold yourself.

## Platform permissions and what they show you

| Permission | Lets you | Hub sections it opens |
|---|---|---|
| `users.list` | See the user directory and roles | Users, Roles (read) |
| `users.manage` | Invite, edit, suspend and delete users | Users actions |
| `entitlements.manage` | Turn apps on and off for anyone | Access |
| `roles.manage` | Create roles and assign them | Roles actions |
| `applications.manage` | Register and review any app | Applications |
| `api_keys.manage` | Manage any API key | API Keys |
| `webhooks.manage` | Manage any webhook | Webhooks |
| `tenants.manage` | Manage tenants and tier changes | Tenant |
| `organizations.manage` | Manage any organization | Organizations |
| `billing.manage` | See and manage subscriptions | Plan & Billing (others) |
| `billing.refund` | Issue refunds | — |
| `audit.view` | Read the audit log | Audit Log |
| `notifications.send` | Send notifications to users | Send notification |

**App owners** don't need any of these for their own apps: owning an app lets you manage its access, keys, webhooks and settings.

{: .note }
The web Hub's Operations console will use `operations.view` and `operations.manage` once the API adds them.

## Seeing a section but not a button

If you can see a screen but an action is greyed out, you can read but not change. Hover over it for the reason, such as "Seed roles can't be edited" or "You're the last admin".
