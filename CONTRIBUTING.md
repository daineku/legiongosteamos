# Contributing

Thanks for helping improve SteamOS on the Legion Go.

## Principles

1. **Publish working fixes only.** A tweak must solve a real, reproducible problem on a real device. Say exactly what was measured or verified, and what was not.
2. **Preserve SteamOS.** No writes under `/usr`, no replacement of Steam components, no Gaming Mode changes unless that is the point of the tweak (and documented).
3. **Small and event-driven.** No polling loops, no background updaters, no new runtimes when SteamOS already ships one.
4. **Reversible.** Every change goes through `lib/backup.sh` (`lg_put_file`, `lg_put_content`, `lg_unit_enable`, ...) so that uninstall can undo it.
5. **Honest status.** `Reference Verified` means the exact implementation works on the reference Legion Go and passes the installer tests. `Cross-device Verified` means independently verified on another SteamOS device. New or untested variants are `Experimental`. Passing ShellCheck or CI is not hardware verification.
7. **Capabilities, not names.** Portable tweaks probe interfaces. Only hardware tweaks (`"hardware": "legion-go"`) check the DMI identity.
8. **Verify for real.** Every tweak with a runtime component needs a `verify.sh` that proves it works, not just that a unit is active.
6. **Feature-level compatibility.** Never drop a tweak because an upstream version number grew. Probe whether SteamOS provides the function and report `upstream-equivalent` when it does.

## Adding a tweak

```
tweaks/<id>/manifest.json  README.md  check.sh  install.sh  uninstall.sh  [adopt.sh] [status.sh]  files/
```

- `README.md` follows the shared guide layout. Keep the language simple; engineering details go to `docs/technical/<id>.md`. Sections:
  - Overview
  - Problem
  - Enhancement
  - User benefit
  - Compatibility
  - Installation
  - Verification
  - Uninstallation
  - Performance (measured, or "not measured")
  - Limitations
  - Technical details
- `check.sh` must change nothing and end with `lg_check_result` (one `RESULT=` line).
- Edit shared KDE files key by key (`kwriteconfig6`), never by replacing the file.
- Do not reference other tweaks' files. Declare a dependency in `manifest.json` instead.

## Before opening a pull request

```bash
tests/run-tests.sh
LG_SHELLCHECK_IMAGE=docker.io/koalaman/shellcheck:stable tests/run-tests.sh static   # if shellcheck is not installed
```

Describe how you verified the change on hardware, and which SteamOS and Steam client versions you used. Never include personal data (Wi-Fi names, account IDs, home paths, tokens) in commits.

## License

By contributing you agree that your contribution is licensed under GPL-3.0-or-later.
