# MB X7 Control 1.0.4

This release corrects several X7 commands after comparing independent HID
captures with Creative's original controller and validating the corresponding
local control paths.

## Corrected hardware control

- Corrected SBX Bass crossover, Front Full-Range and Rear Full-Range parameter
  IDs so they no longer overlap unrelated controls.
- Changed all DSP writes to the X7's exact 14-byte format.
- Uses the dedicated SBX master command so the X7 restores previously enabled
  effects itself.
- Corrected the four-byte Scout Mode command and keeps SBX and Scout mutually
  exclusive in the interface.
- Corrected speaker-layout writes and the two-step transition to headphones.
- SBX Bass is now available with both speaker and headphone output.
- Distance changes now rewrite all six delay parameters and store the actual
  longest configured distance.
- Corrected overall EQ Level to ±6 dB; individual bands remain ±12 dB.
- Detects headphones in either front headphone socket.

## Distribution

Version 1.0.4 remains source-only. Download the source, follow
`GETTING_STARTED.md`, and build MB X7 Control using Xcode 16 or later.
