---
layout: default
title: Versions
nav_order: 99
permalink: /versions/
---

# Versions
{: .no_toc }

Every published version of this Help Center. Each publish gets a new version and a frozen, read-only copy here, so a link to an old version keeps showing exactly what it said, including which app version and which Platform API version it described.
{: .fs-6 .fw-300 }

{% assign current = site.data.versions.current -%}
{% if current -%}
| Docs | Released | Hub for macOS | API spec | `Substratal-Version` | Change |
|---|---|---|---|---|---|
{% assign listed = site.data.versions.archive | unshift: current -%}
{% for v in listed -%}
| [v{{ v.version }}]({{ v.version }}/){% if forloop.first %} **(current)**{% endif %} | {{ v.released }} | {{ v.app_version | default: "—" }} | {{ v.api_spec_version | default: "—" }} | {{ v.api_header_version | default: "—" }} | {{ v.summary | default: "" | replace: "|", "\|" }}{% if v.commit %} ([`{{ v.commit | slice: 0, 7 }}`](https://github.com/CompositeCode/substratalapps-macos/commit/{{ v.commit }})){% endif %} |
{% endfor %}
{% else %}
This is a local build. Version numbers and the archive are assigned only when the site is published from GitHub.
{: .note }
{% endif %}

For what changed in the app, see [Release Notes](../release-notes/). For the API, see its [Changelog](https://compositecode.github.io/substratalapps.com/changelog/).
