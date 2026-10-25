# Changelog

## 1.0.4 — 2026-10-25

- Added continuous hardware reconciliation for current output routing,
  SBX/Scout mode, both headphone sockets, the front microphone socket and
  CoreAudio master state, including physical X7 volume-dial changes.
- Identified the `23 24` query as the X7's three-way SBX/Scout mode status and
  the `23 4D` query as the current headphone/speaker output family.
- Corrected the SBX Bass crossover, Front Full-Range and Rear Full-Range DSP
  parameters, removing collisions with speaker and EQ controls.
- Changed DSP writes to the original controller's exact 14-byte packet format.
- Replaced the emulated SBX master sequence with the X7's dedicated master
  command and made SBX and Scout mutually exclusive in the interface.
- Corrected Scout Mode to its four-byte command and enabled SBX Bass for both
  speaker and headphone output.
- Corrected speaker-layout writes and the two-step headphone-output transition.
- Made distance changes rewrite all six delays and store the calculated longest
  speaker distance on the X7.
- Corrected the overall EQ Level range to ±6 dB while retaining ±12 dB bands.
- Added detection for both front headphone sockets.

## 1.0.3 — 2026-10-10

- Changed MB X7 Control into a menu-bar utility so Open at Login runs quietly
  in the background without leaving an icon in the Dock or Command-Tab.
- Kept the complete controller available from **Show MB X7 Control** in the
  menu-bar menu, along with About, Open at Login, and Quit.

## 1.0.2 — 2026-10-02

- Corrected the SBX Pro Studio master control after tracing Creative's original
  implementation: it now disables individual SBX blocks together and reliably
  restores their saved settings when switched back on.
- Added paced USB writes and a brief in-progress state so the X7 cannot drop
  part of an SBX master transition or accept overlapping master commands.
- Updated first-run and per-control reset values to the original panel defaults:
  Surround 67%, Crystalizer 65%, Dialog Plus 50%, Normal Smart Volume 74%,
  headphone Bass 20%, and headphone crossover 80 Hz.
- Added clearly labelled Default buttons beside the SBX amount and crossover
  controls while preserving each user's saved settings.
- Kept SBX Bass restricted to the active headphone output path.
- Documented the recovered SBX master behavior and corrected the earlier
  interpretation of the X7's recurring hardware-status reports.

## 1.0.1 — 2026-10-02

- Expanded every speaker calibration level control to the original panel's
  full −20 to +20 dB range in 1 dB steps.
- Added Front Center Channel Position controls for Above Screen and Below
  Screen on speaker layouts containing a center channel.
- Changed the fresh-install speaker distance to the original panel's 2.1 m
  starting display and migrated untouched prerelease 0.5 m placeholders.
- Added the application screenshot gallery to the project README.

## 1.0.0 — 2026-10-01

- Initial native Apple-silicon release for macOS 14 and later.
- Added independent USB control for SBX Pro Studio, speaker routing and
  calibration, headphones, Cinematic, Mixer, Equalizer, Scout Mode and
  Advanced Features.
- Added live headphone-jack detection and guarded High Gain and High Power
  controls with explicit safety warnings.
- Added CoreAudio master volume, mute and persistent playback/recording device
  selection.
- Added Playback Mixer volume, mute, balance and readback using public USB
  Audio requests.
- Added automatic USB reconnect handling, per-X7 saved settings, menu-bar
  access and optional Open at Login.
- Added the original MB X7 Control branding, protocol documentation and public
  build, privacy, support and contribution guides.
- Set the initial distribution to source-only through GitHub under the MIT
  License with Commons Clause License Condition v1.0.
- Retained optional Developer ID and notarized DMG tooling for a possible
  future binary release.
