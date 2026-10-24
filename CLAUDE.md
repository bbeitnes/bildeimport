# Bildeimport – notes for Claude Code

A macOS app (SwiftUI, Swift Package Manager) that imports photos and videos from a camera memory card into `<main folder>/YYYY/YYYY-MM-DD/`. The users are elderly, so simplicity and file safety come before features. The full specification, in Norwegian, is in `docs/spesifikasjon.md`.

## Conventions

- All code identifiers, comments, file names and commit messages are in **English**.
- All text the user sees in the app is in **Norwegian bokmål**: labels, messages and the `Ukjent dato` folder name.
- Target: macOS 15+, Apple Silicon only (`arm64`). No App Sandbox. Ad hoc signing only (no Apple Developer account).
- Keep import logic in `Sources/ImportCore` (no SwiftUI or AppKit there) and cover it with tests in `Tests/ImportCoreTests`. UI and system integration (NSWorkspace, NSOpenPanel) live in `Sources/Bildeimport`.

## Safety rules that must never be broken

1. Never write to, move or delete anything on the memory card. Import means copy.
2. Never overwrite an existing file in the destination. Use `DuplicateResolver`.
3. Copy to a hidden temporary name, verify byte for byte, then move to the final name (`Importer.copyVerified`).

## UI rules

- One clear main action per screen, large text (body 19–21 pt, titles 34 pt), high contrast, no menus to hunt in.
- Screens: waiting for card → (choose card) → ready → importing → done → ejected. The design reference is the "Bildeimport – skjermbilder" canvas.

## Commands

```bash
swift test
swift run Bildeimport
scripts/build-dmg.sh 1.0.0
```

Pushing a tag `vX.Y.Z` makes GitHub Actions build the DMG and publish a release.
