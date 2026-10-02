# MB X7 Control 1.0.2

Reliability and defaults update for the native Apple-silicon macOS controller
for the Creative Sound Blaster X7.

Project: `alcatron/mb-x7-control`

Maintainer: [alcatron](https://github.com/alcatron)

## Changes since 1.0.1

- Corrected the SBX Pro Studio master control after tracing the behavior of
  Creative's original application. The master now disables the individual SBX
  processing blocks together and restores the complete saved SBX state when
  switched back on.
- Paced the USB writes used by the SBX master and blocked overlapping clicks
  during its brief transition, preventing partial restores on the X7.
- Added the original panel's first-run and reset values: Surround 67%,
  Crystalizer 65%, Dialog Plus 50%, Normal Smart Volume 74%, headphone Bass
  20%, and headphone crossover 80 Hz.
- Added visible Default buttons beside each SBX amount and crossover control.
  Existing saved user settings continue to take priority.
- Ensured SBX Bass is restored only while headphones are connected and selected
  as the active output.
- Expanded the protocol notes with the independently recovered SBX master
  behavior and clarified that recurring `23 4C`/`23 4D` reports are hardware
  status polling rather than the master command.

## Distribution

Version 1.0.2 remains source-only. Download the source and build MB X7 Control
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
