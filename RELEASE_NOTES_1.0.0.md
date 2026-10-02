# MB X7 Control 1.0.0

Initial public release of a native Apple-silicon macOS controller for the
Creative Sound Blaster X7.

Project: `alcatron/mb-x7-control`

Maintainer: [alcatron](https://github.com/alcatron)

## Distribution

This initial release is source-only. Download the source and build MB X7
Control locally with Xcode 16 or later. A paid Apple Developer membership is
not required. See the
[Getting Started guide](https://github.com/alcatron/mb-x7-control/blob/main/GETTING_STARTED.md)
for complete build, installation and first-use instructions.

Developer ID signing and Apple notarization are deferred for a possible future
downloadable binary release.

## Highlights

- Native Speakers and Headphones output control with front-jack detection
- SBX Pro Studio, speaker routing and calibration, Cinematic, Mixer, EQ,
  Scout Mode, headphone gain, and Advanced controls
- Speaker calibration from −20 to +20 dB, 0.5 to 5.0 m, plus front-center
  Above/Below Screen positioning
- Playback Mixer volume, mute, and balance through public USB Audio requests
- CoreAudio master volume, mute, and playback/recording device selection
- Persistent menu-bar access and optional Open at Login
- No Creative application or private Creative framework required at runtime

## Requirements

- Apple silicon Mac
- macOS 14 or later
- Creative Sound Blaster X7 connected by USB

## Safety

High Power Amplification and 600-ohm Headphone High Gain are guarded by
explicit warnings. Read those warnings and confirm that the connected hardware
meets the requirements before enabling either option.

## Independence and licence

MB X7 Control is independently developed for hardware interoperability and is
not affiliated with or endorsed by Creative Technology Ltd.

The project is free and source-available under the MIT License with the Commons
Clause License Condition v1.0. Sale and commercial monetisation substantially
based on MB X7 Control are not permitted by the licence.
