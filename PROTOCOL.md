# Sound Blaster X7 macOS control protocol

These interoperability notes document behavior independently observed from a
physical X7 and the legacy macOS control panel. MB X7 Control uses only public
macOS APIs and does not copy or link Creative binaries or frameworks.

## Conventions
- `CONFIRMED`: observed in isolated or repeated live captures.
- DSP packet family commonly observed as: `20 00 16 0A D5 02 [param_hi param_lo] [namespace] [float32 BE] 4D 00`.
- `20 96` and `20 97` are distinct namespaces/contexts and must not be conflated.
- Float values in DSP packets are IEEE-754 big-endian float32.
- Mixer SoundCore dB values are signed int16 little-endian.

# 1. SBX Pro Studio — namespace 20 96

| Function | Parameter | Encoding | Confirmed values |
|---|---:|---|---|
| Surround enable | `08 00` | float32 BE | `0.0` OFF, `1.0` ON |
| Surround amount | `08 02` | float32 BE | continuous `0.0..1.0` |
| Dialog Plus enable | `08 04` | float32 BE | `0.0` OFF, `1.0` ON |
| Dialog Plus amount | `08 06` | float32 BE | continuous `0.0..1.0` |
| Smart Volume enable | `08 08` | float32 BE | `0.0` OFF, `1.0` ON |
| Smart Volume amount | `08 0A` | float32 BE | continuous `0.0..1.0` (active in Normal mode) |
| Smart Volume mode | `08 0C` | float32 BE enum | `0.0` Normal, `1.0` Loud, `2.0` Night |
| Crystalizer enable | `08 0E` | float32 BE | `0.0` OFF, `1.0` ON |
| Crystalizer amount | `08 10` | float32 BE | continuous `0.0..1.0` |
| SBX Bass enable | `08 30` | float32 BE | `0.0` OFF, `1.0` ON |
| SBX Bass amount | `08 32` | float32 BE | continuous `0.0..1.0` |
| SBX Bass crossover | `08 34` | float32 BE | frequency in Hz; Creative default `80` |

SBX Bass is gated by the X7 headphone output path. Its enable, amount, and
crossover controls were recovered as `08 30`, `08 32`, and `08 34` in the
`20 96` namespace.

The SBX master button is not a standalone HID toggle. The original panel calls
SoundCore parameter `0x7000000100000009` with a two-byte `[1, state]` payload;
its `CEfxMasterControlClient` then disables the supported SBX effects together
and restores their saved enable states when switched back on. MB X7 Control
reproduces that resulting behavior with the independently verified explicit
SBX parameters above. Two-byte reports such as `23 4C` and `23 4D` are part of
the legacy panel's recurring hardware-status polling and are not used as the
SBX master command.

# 2. Equalizer — namespace 20 96

| Function | Parameter |
|---|---:|
| EQ enable | `08 12` |
| Overall Level | `08 14` |
| 31 Hz | `08 16` |
| 62 Hz | `08 18` |
| 125 Hz | `08 1A` |
| 250 Hz | `08 1C` |
| 500 Hz | `08 1E` |
| 1 kHz | `08 20` |
| 2 kHz | `08 22` |
| 4 kHz | `08 24` |
| 8 kHz | `08 26` |
| 16 kHz | `08 28` |

- Enable: float32 BE `0.0` OFF / `1.0` ON.
- Level/bands: signed float32 BE values; UI permits continuous movement.

## Factory EQ presets captured
Order: `Level, 31, 62, 125, 250, 500, 1K, 2K, 4K, 8K, 16K` (dB)

| Preset | Values |
|---|---|
| Flat | `0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0` |
| Acoustic | `0, 0, 1, 2, 0, 0, 0, 0, 2, 2, 2` |
| Classical | `0, 0, 6, 6, 3, 0, 0, 0, 0, 3, 3` |
| Country | `0, -1, 0, 1, 1, 1, 0, 0, 2, 3, 4` |
| Dance | `0, -1, 2, 3, 4, -1, -1, 0, 0, 4, 4` |
| Jazz | `0, 0, 0, 1, 4, 4, 4, 0, 1, 3, 3` |
| New Age | `0, 0, 2, 2, 0, 0, 0, 1, 2, 2, 2` |
| Pop | `0, -2, 0, 2, 2, 0, -1, -1, 0, 3, 6` |
| Rock | `0, -1, -1, 1, 2, -1, -1, 0, 0, 4, 4` |
| Vocal | `0, -2, -1, -1, 0, 3, 4, 3, 0, 0, 1` |

Selecting a factory preset was observed to write the complete EQ state rather than a separate preset-ID command in the monitored path.

# 3. Speakers / Bass management — namespace 20 96

## Speaker configuration HID report

`23 4E` followed by a little-endian UInt32 channel mask:

| Layout | Mask |
|---|---:|
| 2.0 | `0x00003003` |
| 2.1 | `0x0000B007` |
| 3.0 | `0x00007007` |
| 3.1 | `0x0000F00F` |
| 4.0 | `0x00033033` |
| 4.1 | `0x0003B03B` |
| 5.0 | `0x00037037` |
| 5.1 | `0x0003F03F` |

The earlier `08 08 / 20 96` speaker enum capture is not used; that identifier is
the independently verified Smart Volume enable parameter.

## Output target and speaker flags

- Output target: `5A 2C 05 00` + UInt32 LE (`1` Line Out, `2` Amplifier Out, `3` Both)
- Front L/R full-range: `08 1A / 20 96` (`0.0` full-range, `1.0` normal)
- Rear L/R full-range: `08 1C / 20 96` (`0.0` full-range, `1.0` normal)
- High Power Amplification: `23 59 00|01`
- Headphone Surround for Line/Optical Out: `5A 39 03 00 0A 00|01`

## Bass management

| Function | Parameter | Values |
|---|---:|---|
| Bass Redirection | `08 2A` | `0.0` OFF / `1.0` ON |
| Crossover Frequency | `08 2C` | float32 BE Hz; confirmed 10.0–500.0 Hz |
| Subwoofer Gain | `08 3C` | `0.0` OFF / `1.0` ON |

Changing/removing Subwoofer was observed to clear dependent settings in some transitions. The nearby `08 30` traffic was subsequently isolated as headphone-path SBX Bass enable, not speaker Bass Redirection.

# 4. Speaker calibration channel map — namespace 20 96

Front-center vertical placement uses `08 40`: `1.0` = Above Screen and
`0.0` = Below Screen. The mapping was recovered from the original panel's
`radioButtonSelected:` path (`0x96`, command `0x20` in its Bluetooth protocol;
USB SoundCore parameter IDs are twice those command IDs).

| Channel | Level | Polarity/calibration-associated | Distance |
|---|---:|---:|---:|
| Front Left | `08 42` | `08 52` | `08 62` |
| Front Right | `08 44` | `08 54` | `08 64` |
| Front Center | `08 46` | `08 56` | `08 66` |
| Subwoofer | `08 48` | `08 58` | `08 68` |
| Rear Left | `08 4A` | `08 5A` | `08 6A` |
| Rear Right | `08 4C` | `08 5C` | `08 6C` |

- Level values: signed float32 BE, −20.0 through +20.0 in 1 dB steps. The
  original panel binary checks the controls against exact endpoints `-0x14`
  and `0x14`; captures included `+1.0`, `0.0`, and `-1.0` examples.
- `08 52..5C` are per-channel polarity values: `0.0` normal, `1.0` inverted.
- Distance UI range is 50–500 cm in 10 cm steps. The device value is relative
  delay in seconds: `(longestDistanceCM - channelDistanceCM) * 2.91188631995807e-5`.
  Creative's panel writes all six delay values after a distance change and
  separately tracks the longest displayed distance. Its visible default is
  210 cm; equal 210 cm channel distances therefore send zero relative delay.

# 5. Speaker model and speaker preset HID family

## Speaker model
Observed packets:
- `5A 2A 03 00 00 00` → speaker model 0
- `5A 2A 03 00 01 00` → speaker model 1

The product-facing model names are:
- `0` = Other Speakers
- `1` = E-MU XM7

Model 1 exposed the E-MU XM7 voicing choices Energetic, Neutral, and Warm;
model 0 exposed no voicing choices in the observed capture.

## Speaker preset
Observed packet family:
- `5A 2B 03 00 [preset] 00`

Confirmed indices and product-facing labels:
- `0` = Energetic
- `1` = Neutral
- `2` = Warm

# 6. Direct modes / Headphones

| Function | HID report |
|---|---|
| Direct Mode OFF | `23 43 00` |
| Direct Mode ON | `23 43 01` |
| Direct Mode (SPDIF-In) OFF | `23 4B 00` |
| Direct Mode (SPDIF-In) ON | `23 4B 01` |
| Headphone Normal Gain (32–300 ohm) | `23 45 00` |
| Headphone High Gain (600 ohm) | `23 45 01` |

The headphone-gain values were recovered from the local Creative control flow.
Normal Gain was also observed directly. High Gain was not physically activated
during verification because Creative warns that mismatched headphones may be
damaged; MB X7 Control therefore requires explicit confirmation before sending
it.

# 7. Output selection (physical headphones connected)

Confirmed isolated transitions:
- Speakers: `23 4E 00 00 00 80`
- Headphones: `23 4E 01 00 00 00`

Preserve the complete captured reports; do not assume only the state byte differs.

The selector became active only after a headphone plug was physically detected.

## Front headphone-jack detection

The X7 uses its public HID interface, not the older Creative U2 USB-device
request. Send output report `23 12` with report ID 0. The 16-byte input reply
starts `00 23 12`; bit 2 of byte 4 reports the front headphone jack (`00` when
empty, `04` when inserted). The original panel receives the same state through
CTMalcolm's HID input callback and publishes it as its second headphone jack.
MB X7 Control performs the query independently with public IOKit APIs.

# 8. Cinematic / Dolby Digital Dynamic Range Control — namespace 20 97

Parameter: `08 04` (NOTE: same parameter ID as SBX Dialog Plus but DIFFERENT namespace)

| Mode | Float enum |
|---|---:|
| Full (maximum) | `1.0` |
| Normal (standard) | `2.0` |
| Night (minimum) | `3.0` |

# 9. Scout Mode

Confirmed HID reports:
- ON:  `23 23 02 01 03 00 00 04`
- OFF: `23 23 02 00 03 00 00 04`

The state byte is the fourth byte (`01`/`00`) in these captured reports. A separate short `23 24 ...` report was observed around Scout Mode but remains unidentified.

# 10. Auto Standby / AutoSleep

Feature-control family:
- ON:  `5A 39 03 00 0B 01`
- OFF: `5A 39 03 00 0B 00`

Feature ID `0x0B` corresponds to AutoSleep/Auto Standby in the observed app diagnostics.

# 11. Playback Mixer — independent USB Audio transport

The five source strips were confirmed with sequential Unit IDs:

| Unit ID | Source |
|---:|---|
| `0x0F` | Mic-In/Mic Array |
| `0x10` | Line In |
| `0x11` | Bluetooth |
| `0x12` | SPDIF-In |
| `0x13` | USB Host |

## Source volume / L-R balance

Objective-C path:
`MixerViewController sliderChanged:` → `SoundCoreMgr setParamValueEx:::`

Arguments observed:
- parameter (`rdx`) = `0x7000000100000011`
- index (`rcx`) = `0`
- length (`r8`) = `6`
- payload pointer (`r9`)

6-byte payload structure:
`[UnitID] [aux] [dB_LO] [dB_HI] [channel] [01]`

- dB = signed int16 little-endian.
- channel `00` = source master/all
- channel `01` = Left
- channel `02` = Right
- byte 1 (`aux`) varied in captures and remains UNKNOWN; do not hard-code an inferred meaning.

Confirmed examples:
- Mic master: `0F 00 F9 FF 00 01` = -7 dB
- Line In master: `10 00 F7 FF 00 01` = -9 dB
- Bluetooth master: `11 00 F7 FF 00 01` = -9 dB
- SPDIF-In master: `12 00 F8 FF 00 01` = -8 dB
- USB Host master: `13 00 FA FF 00 01` = -6 dB
- Mic Left: `0F 00 EB FF 01 01` = -21 dB
- Mic Right: `0F 00 01 00 02 01` = +1 dB

## Source mute

Same SoundCoreMgr call, parameter:
`0x7000000100000010`

Confirmed semantic field:
- bytes 2–3 = `01 00` → muted
- bytes 2–3 = `00 00` → unmuted

Confirmed on Mic and independently on Line In, supporting generic use across known Unit IDs.

Examples:
- Mic mute captured: `0F 00 01 00 00 01`
- Mic unmute captured with varying aux byte: `0F 2E 00 00 00 01`
- Line In mute: `10 9A 01 00 00 01`

Again, byte 1 is variable in SoundCore, but lower-level tracing proved it is not
part of the USB request.

## Public transport

The decoded values are sent to `IOUSBInterface` 0, configuration 1, on device
`041e:323a` with USB Audio class requests:

- mute SET_CUR: `21 01`, `wValue=0100`, `wIndex=UnitID<<8`, one-byte value;
- volume SET_CUR: `21 01`, `wValue=0200|channel`, `wIndex=UnitID<<8`, signed LE 8.8 dB;
- current GET_CUR: `A1 81` with the corresponding selector/channel;
- volume range: `A1 02`, selector 2/channel 1, UAC2 range response.

This path is implemented with public IOKit only. An independent physical-device
test read every source and successfully changed, observed, and restored Mic-In
mute, then rewrote the unchanged stereo volume.

# 12. Playback Mixer — Speakers master via CTVolumeManager/CoreAudio

## Master volume
Path:
`MixerViewController sliderChanged:` → `VolumeManager setVolume:isInput:` → `AudioObjectSetPropertyData`

Observed:
- `isInput = 0` for Speakers/output.
- incoming master volume is a float32 scalar in XMM0.
- captured example raw bytes `88 E2 AD 3E` ≈ 0.3396 (~34%).
- CoreAudio write observed with AudioObjectID `0x86`, data size 4 bytes.

The disassembly showed support for channel-specific L/R writes depending on balance; only one CoreAudio write was directly observed in the isolated event, so do not claim two writes are always emitted.

## Master mute
Path:
`MixerViewController speakerMuteButtonClicked:` → `VolumeManager setMute:isInput:` → `AudioObjectSetPropertyData`

Observed AudioObjectID `0x86`, 4-byte value:
- muted:   `01 00 00 00`
- unmuted: `00 00 00 00`

# 13. Controls not fully mapped / unavailable

- CrystalVoice: controls greyed out in current macOS configuration.
- Some Recording mixer controls: greyed/unavailable.
- SoundCore Mixer payload byte 1 remains semantically unknown but is discarded
  before USB transport and is not required by the independent implementation.
- `23 24 ...`: observed around Scout Mode; unknown.
- Headphone gain: `23 45 00` Normal / `23 45 01` High Gain. The app guards High Gain with an explicit safety confirmation.
- Custom EQ Save/Delete: not reverse-engineered; likely app-side preset management and not required to control DSP state.

# 14. Implementation rule

Implementations must preserve the exact confirmed packet/report families and
namespaces. Do not collapse parameters solely because their `08 xx` IDs match
across namespaces (for example, `08 04 / 20 96` SBX Dialog Plus and
`08 04 / 20 97` Dolby DRC).

Before shipping any write path, verify it against the X7 with Creative Control Panel closed and provide a read/query or safe restore path where possible.
