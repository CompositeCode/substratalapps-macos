---
layout: default
title: Invite a user
parent: Tutorials
nav_order: 1
permalink: /tutorials/invite-a-user/
screens: [USR-01, USR-02, USR-03]
---

# Invite a user
{: .no_toc }

Create an account for someone and email them an invitation.
{: .fs-6 .fw-300 }

{% include availability.html %}

**You'll need:** the `users.manage` permission (the `superadmin` role has it).

1. In the sidebar, under **Administration**, choose **Users** (⌥⌘1).
2. Choose **Invite User** in the toolbar (or press ⇧⌘N).
3. Enter their **Email**. **Display name** is optional; they can change it later.
4. Leave **Send invitation email** on. They get a link to set a password and finish signing up.
5. Choose **Invite**.

The new user opens with status **Invited**. When they accept, the status changes to **Active**.

## Variations

- **Create as active:** turn on **Create as active** to skip the invitation, for example for a service account that signs in another way. They still need to set a password through **Forgot password**.
- **Already exists:** if someone already has an account with that email, you'll see "A user with that email exists" with a link to their account.
- **Resend:** if the invitation expired or went to spam, open the user and choose **Resend invitation**.

## What happens behind the scenes

The app calls `POST /users` with an `Idempotency-Key`, so a retry after a network drop never creates two accounts. The invitation is recorded in the [Audit Log](investigate-with-the-audit-log/) as `user.created`.

{: .note }
Invitation emails reach real inboxes only once the platform's email sending is out of the Amazon SES sandbox. Until then, only verified addresses receive them.
