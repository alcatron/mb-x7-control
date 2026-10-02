# MB X7 Control 1.0.1

Maintenance update for the native Apple-silicon macOS controller for the
Creative Sound Blaster X7.

Project: `alcatron/mb-x7-control`

Maintainer: [alcatron](https://github.com/alcatron)

## Changes since 1.0.0

- Expanded all speaker calibration level controls to −20 through +20 dB in
  1 dB steps, matching the original Creative panel.
- Added Front Center Channel Position controls for Above Screen and Below
  Screen. They become available with 3.x and 5.x layouts containing a center
  speaker.
- Set the fresh-install speaker distance display to 2.1 m and safely migrated
  untouched prerelease 0.5 m placeholders while retaining other calibrated
  distances.
- Added a complete application screenshot gallery to the README.

## Distribution

Version 1.0.1 remains source-only. Download the source and build MB X7 Control
locally with Xcode 16 or later. A paid Apple Developer membership is not
required. See the
[Getting Started guide](https://github.com/alcatron/mb-x7-control/blob/main/GETTING_STARTED.md)
for build, installation and first-use instructions.

Developer ID signing and Apple notarization remain deferred for a possible
future downloadable binary release.

## Requirements

- Apple silicon Mac
- macOS 14 or later
- Creative Sound Blaster X7 connected by USB

## Independence and licence

MB X7 Control is independently developed for hardware interoperability and is
not affiliated with or endorsed by Creative Technology Ltd.

The project is free and source-available under the MIT License with the Commons
Clause License Condition v1.0. Sale and commercial monetisation substantially
based on MB X7 Control are not permitted by the licence.
