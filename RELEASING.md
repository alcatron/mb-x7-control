# Release process

The current MB X7 Control release is source-only. Developer ID signing and
Apple notarization are deliberately deferred and are not blockers for the
source distribution through GitHub.

## Release target

- Product: MB X7 Control
- Version: 1.0.1 (2)
- Platform: macOS 14 or later
- Architecture: arm64 only
- Initial distribution: source-only through GitHub
- Licence: MIT plus Commons Clause License Condition v1.0
- Bundle identifier: `io.github.alcatron.MBX7Control`
- Repository: `alcatron/mb-x7-control`
- Project owner/maintainer: `alcatron`

## Initial source release

Before publishing the source:

1. Complete the local preflight with `./scripts/preflight.sh`.
2. Confirm the project builds and runs from a clean checkout using Xcode 16 or
   later without a paid Apple Developer membership.
3. Test the physical X7 functions listed under **Required verification**.
4. Confirm `README.md`, `GETTING_STARTED.md`, the licence, privacy statement,
   support information and release notes match the source being released.
5. Review the repository for credentials, personal data, build products,
   Creative binaries and private Creative frameworks.

The initial GitHub release should contain the tagged source code and link to
`GETTING_STARTED.md`. It should not advertise an unsigned prebuilt application
or DMG as a normal consumer download.

## Possible future binary release

The existing binary-release tooling is retained for later. If a downloadable
binary is offered in the future, complete these one-time prerequisites:

1. Enrol the copyright owner in the Apple Developer Program.
2. Register the permanent bundle identifier `io.github.alcatron.MBX7Control`
   with Apple.
3. Install a `Developer ID Application` certificate in the login keychain.
4. Store notarization credentials in the keychain with `notarytool` and choose
   a profile name. Never commit passwords, API private keys, or credentials.

### Build and package the future binary

The release script deliberately refuses to run without explicit signing and
notarization values:

```sh
DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="MBX7-notary" \
./scripts/release.sh
```

It archives the shared Xcode scheme, exports a Developer ID build, verifies
the app, creates and signs a DMG, submits it for notarization, staples the
ticket, and writes a SHA-256 checksum. Outputs are placed in `dist/`, which is
ignored by Git.

## Required verification

- Clean Release build and static analysis succeed.
- The executable is arm64 and the minimum macOS version is 14.0.
- A clean source download opens, builds and runs using the published getting
  started instructions.
- The installed app launches, detects a physical X7, and shows all sidebar
  sections at the minimum window size.
- Speakers/Headphones gating, Mixer readback, saved mutes, audio-device
  selection, menu-bar access, Open at Login, About, warnings, and reconnect
  behaviour receive a final smoke test.
- Licence, privacy, support, release notes, version, screenshots, and source tag
  match the released project.

For a future binary release, additionally verify that Hardened Runtime is
enabled, `get-task-allow` is absent, code-signature and Gatekeeper assessment
succeed, notarization is stapled and valid, the DMG installs correctly, and its
published SHA-256 checksum matches.

## Publication boundary

Creating a public repository, pushing source, tagging a release, creating a
GitHub Release, and uploading any artifact are separate manual publication
actions. Neither script publishes anything.
