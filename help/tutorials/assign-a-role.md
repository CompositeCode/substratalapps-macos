---
layout: default
title: Give someone a role
parent: Tutorials
nav_order: 3
permalink: /tutorials/assign-a-role/
screens: [USR-03, ROL-01, ROL-02, ROL-04]
---

# Give someone a role
{: .no_toc }

Roles decide what a person can do: on the platform (for staff) or inside one app.
{: .fs-6 .fw-300 }

{% include availability.html %}

**You'll need:** `roles.manage`. For a platform role, you also need every permission the role grants: nobody can give out more than they hold.

1. Open **Users** (⌥⌘1), select the person, and choose the **Roles** tab.
2. Choose **Assign role**, search for the role, and select it.
3. The role appears in the list straight away. Assigning a role they already hold does nothing.

To remove a role, select it and press **⌘⌫**, or use its **Remove** button. Two kinds of role can't be removed:

- **member**: every account holds this platform role.
- Roles marked **Granted with app access**: an app's default role, which comes with access to the app and goes when access is turned off.

## See who holds a role

Open **Roles** (⌥⌘3) and select the role. **People with this role** lists everyone it's assigned to.

## Create a role

1. In **Roles**, choose **New Role** (⇧⌘N).
2. Choose the scope: **Platform** for staff permissions, or an app for that app's own permissions.
3. Name it and tick its permissions. Choose **Create**.

The built-in roles (`superadmin`, `support`, `billing_admin`, `member`) can't be edited. See [Roles and permissions](../concepts/roles-and-permissions/) for what each permission allows.
