---
layout: default
title: How access works
parent: Concepts
nav_order: 1
permalink: /concepts/how-access-works/
---

# How access works
{: .no_toc }

Two questions decide what a person can do in an app, always in this order.
{: .fs-6 .fw-300 }

1. TOC
{: toc }

---

## 1. Is the app on for them?

That's the **entitlement**: the on/off switch between a person and an app. The Hub shows it as a status badge and a switch.

| Status | Meaning | Can they use the app? |
|---|---|---|
| **Active** | On. | Yes |
| **Scheduled** | On, starting later. | Not yet |
| **Disabled** | Turned off by an admin. Reversible. | No |
| **Expired** | A trial or subscription ran out. | No |
| **Revoked** | The purchase itself was removed (refund, chargeback). | No |
| **None** | No access at all. | No |

Turning an app off changes only this switch. Their roles, profile and settings in the app are kept, and come back when it's turned on again.

## 2. If it's on, what can they do?

That's their **roles**, each a set of **permissions**. See [Roles and permissions](../roles-and-permissions/). A role does nothing while the app is off for them.

## Where access comes from

A person can have several paths to the same app at once. The app is on if **any** path is on.

| Path | Comes from | Can you edit it? |
|---|---|---|
| **Free** | Every account gets free apps. | Turn off and on only ("Managed by Substratal") |
| **Standard** | Their own $6/month subscription, or an organization's. | Turn off and on only |
| **Purchase**, **Trial**, **Admin grant** | Given by an admin or the app's developer. | Yes |
| **Organization seat** | An organization granted the app to its members. | By that organization's admins |

Choose **Why?** on a person's Access tab to see every path and which one decides.

{: .important }
Turning off one organization's seat never removes access the person has another way. The app stays on if another path is active.

## How apps find out

Apps don't work this out themselves. They ask the platform, or listen for webhooks such as `access.revoked`, so a change you make in the Hub reaches the app within minutes at most.
