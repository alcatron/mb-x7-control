# Getting started

MB X7 Control 1.0 is distributed as source code. You build your own local copy
with Xcode; an Apple Developer Program membership is not required.

## What you need

- An Apple silicon Mac
- macOS 14 or later
- A Creative Sound Blaster X7 connected directly by USB
- Xcode 16 or later, available free from the Mac App Store

MB X7 Control controls the X7 through its USB connection. Bluetooth control is
not supported. Creative's X7 Control Panel and private Creative frameworks are
not required.

## Download the source

1. Open `https://github.com/alcatron/mb-x7-control`.
2. Select **Code**, then **Download ZIP**.
3. Open the downloaded ZIP and move the resulting folder somewhere permanent.

Git users may instead clone `https://github.com/alcatron/mb-x7-control.git`.

## Build and run with Xcode

1. Open `X7Control.xcodeproj` from the downloaded folder.
2. If macOS asks whether you trust the project, confirm only if you obtained it
   from the official `alcatron/mb-x7-control` repository.
3. At the top of Xcode, select the **X7Control** scheme and **My Mac** as the
   destination.
4. Press **Command-R**, or select **Product > Run**.
5. Wait for Xcode to build and open MB X7 Control.

The project can build locally without a paid Apple Developer membership. If
Xcode offers to use a Personal Team, that is optional for running this macOS
application on your own Mac.

## Keep the app in Applications

After a successful build:

1. In Xcode, select **Product > Show Build Folder in Finder**.
2. Open `Products`, then `Debug`.
3. Quit MB X7 Control if it is running.
4. Drag **MB X7 Control.app** into your **Applications** folder.
5. Open it from Applications.

This is a locally built application, not the future Developer ID signed and
notarized binary. Only build source obtained from a repository you trust.

## First use

1. Power on the X7 and connect it to the Mac by USB.
2. Open MB X7 Control. The header should show **Connected via USB**.
3. Plug headphones into either front headphone socket before selecting
   **Headphones**. The smaller socket is 3.5 mm and the larger socket is
   6.35 mm; both use the same headphone output path.
4. Use **Speakers** for speaker layout, routing, calibration, polarity and bass
   management.
5. Use **Mixer** for X7 master volume/mute and the five playback-source volume,
   mute and balance controls.
6. Use the menu beside the output selector to choose the Mac's playback and
   recording devices, restore supported defaults, view About, or enable
   **Open at Login**.

Settings supported by the X7 are sent when you change them. MB X7 Control also
remembers its supported local choices, including selected macOS audio devices
and Mixer mute state.

## Safety

- Leave **Headphone Gain** on Normal unless you are using headphones designed
  for the X7's 600-ohm High Gain mode.
- Enable **High Power Amplification** only with compatible 4-ohm passive
  speakers, the X7 impedance switch set to 4 ohms, and the appropriate 24 V,
  6 A high-output power adapter.
- Read and accept the in-app warning before enabling either high-power mode.

## If the X7 is not detected

1. Confirm the X7 is powered on and connected directly by USB rather than only
   by Bluetooth.
2. Check **System Settings > Sound** to confirm macOS can see the X7.
3. Disconnect and reconnect the USB cable, then use the refresh button in MB X7
   Control.
4. Quit both Creative's legacy control panel and MB X7 Control if either is
   unresponsive, then reopen only MB X7 Control.
5. Try another USB cable or port and avoid an unpowered hub.

For reproducible problems, see [`SUPPORT.md`](SUPPORT.md).
