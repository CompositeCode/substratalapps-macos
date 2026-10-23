---
layout: default
title: Test mode and live mode
parent: Concepts
nav_order: 4
permalink: /concepts/test-and-live-mode/
---

# Test mode and live mode
{: .no_toc }

Build and try things next to real users without touching them.
{: .fs-6 .fw-300 }

Users, API keys, webhooks, devices, notifications and subscriptions are each either **live** or **test**. The two never see each other:

- A **test** API key only sees test-mode users and data.
- A **live** key only sees live data.
- Test-mode users expire: 24 hours after they're created unless you choose a later time (up to 30 days). After that they can't sign in, and their data is removed after 30 days.

In the Hub, test-mode rows are labelled **Test**. When the app is connected to the local devserver, the sign-in screen offers **Test-mode account**.

{: .tip }
Test-mode subscriptions use Stripe's test mode and test cards, on a deployment that has Stripe test keys (such as the local devserver). Where there are none, the API says so (`test_mode_billing_unavailable`).
