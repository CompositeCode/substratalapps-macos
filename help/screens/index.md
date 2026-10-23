---
layout: default
title: Screen Reference
nav_order: 5
has_children: true
permalink: /screens/
---

# Screen Reference
{: .no_toc }

Every screen in Substratal Hub, by area. Each has the same ID on every platform. In the app, the ID is under the window title, and **Help → Help for This Screen** opens its page here.
{: .fs-6 .fw-300 }

These pages are generated from the app's screen catalog every time the app changes, so they always list exactly the screens the app has, and say which are built in this version.

{% assign groups = site.data.screens.screens | group_by: "domain" -%}
| Area | Screens |
|---|---|
{% for group in groups -%}
{%- assign parts = group.name | split: " " -%}
{%- assign code = parts | first -%}
{%- assign name = group.name | remove_first: code | strip -%}
{%- assign slug = group.name | slugify -%}
| [{{ name }}]({{ '/screens/' | append: slug | append: '/' | relative_url }}) | {{ group.items.size }} |
{% endfor %}
