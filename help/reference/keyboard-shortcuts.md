---
layout: default
title: Keyboard Shortcuts
parent: Reference
nav_order: 1
permalink: /reference/keyboard-shortcuts/
---

# Keyboard Shortcuts
{: .no_toc }

Every shortcut is also in a menu, so you can always find it there.
{: .fs-6 .fw-300 }

{: .macos }
These are the macOS app's shortcuts. The web Hub uses Ctrl in place of ⌘ on Windows and Linux.

## Go to a section

The **Go** menu. Generated from the app's own screen catalog, so it always matches the app.

| Shortcut | Goes to | Section |
|---|---|---|
{% for screen in site.data.screens.screens -%}
{%- if screen.sidebar and screen.sidebar.shortcut -%}
{%- assign keys = screen.sidebar.shortcut | replace: "ctrl+", "⌃" | replace: "opt+", "⌥" | replace: "shift+", "⇧" | replace: "cmd+", "⌘" -%}
| **{{ keys }}** | [{{ screen.sidebar.label }}]({{ '/screens/' | append: screen.id | downcase | append: '/' | relative_url }}) | {{ screen.sidebar.section | capitalize }} |
{% endif -%}
{%- endfor %}

## Everywhere

| Shortcut | Action | Menu |
|---|---|---|
| **⌘K** | Command palette: find any user, app, key or event | Go |
| **⌘N** | New window | File |
| **⇧⌘N** | New item on this screen (Invite user, New role, Create key…) | File |
| **⌘F** | Search this list | Edit |
| **⌘R** | Refresh | View |
| **⌃⌘S** | Show or hide the sidebar | View |
| **⌥⌘I** | Show or hide the inspector | View |
| **⌘,** | Settings | Substratal Hub |
| **⌘?** | Substratal Hub Help | Help |

## Lists and tables

| Shortcut | Action |
|---|---|
| Click, **⇧**-click, **⌘**-click, **⌘A** | Select one, a range, several, or all |
| **Space** | Preview the selected row |
| **⌘C** | Copy the selected row's ID |
| **⌘⌫** | Remove, revoke or suspend the selection (asks first) |
| **⌘Z** | Undo turning access on or off (within 10 seconds) |
| **⇧⌘U** | Mark all as read (Inbox) |

## Forms and sheets

| Shortcut | Action |
|---|---|
| **⌘↩** | Submit |
| **Esc** | Cancel |
