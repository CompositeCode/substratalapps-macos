# Changelog

Every release of Substratal Hub for macOS. The Help Center's Release Notes page is generated from this file. Add an entry under **Unreleased** with every change people will notice; the release workflow moves it under the version number.

## Unreleased

### Added

- The app skeleton: sidebar navigation for all 75 screens in the UI spec (Personal, Administration, Developer), gated by what your account can do. Screens that aren't built yet show what they're for and link to their help page.
- Sign in with email and password, and two-factor sign-in with an authenticator code or a recovery code. Your session is kept in the macOS Keychain and refreshed automatically.
- **Users** (USR-01): search the user directory by name, email or ID, filter by status, and load more as you scroll.
- **Settings → Appearance**: Match System, Light or Dark, and any of the five light and five dark Substratal themes.
- **Settings → Connection**: switch between production and a local API devserver. Each keeps its own session.
- Help menu: Help Center, help for the current screen, tutorials, keyboard shortcuts, FAQ, release notes, and the Platform API reference.
- Update notices: a banner when this version of the app is deprecated by the API, and a stop with "Update required" when the API no longer supports it.

### Platform API

- Built against API spec `1.0.0-draft.9` (API v1.8.0), version header `Substratal-Version: 1`. Paths have no `/v1` prefix.
