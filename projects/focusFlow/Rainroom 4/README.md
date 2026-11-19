# Rainroom

A personal, offline iPhone rain player built in SwiftUI. Requires iOS 17 or later.

## Run on your iPhone

1. Open `Rainroom.xcodeproj` in Xcode.
2. Select the Rainroom target, then Signing & Capabilities.
3. Select your Apple development team. Change the bundle identifier if Xcode asks for a unique one.
4. Connect your iPhone, select it as the run destination, and press Run. Enable Developer Mode on the phone if prompted.

A free Apple ID can be used for personal device development; Xcode may require periodic reinstallation with free signing.

## Features

- Three bundled stereo rain textures: Soft, Steady, and Heavy.
- Continuous looping, volume control, and saved sound/volume preferences.
- Background playback and lock-screen play/pause controls.
- Sleep timer: 15, 30, 45, 60, 90, or 120 minutes. This is elapsed wall-clock time, including pauses. Selecting Off cancels it.
- Pauses when headphones disconnect; handles audio interruptions.
- VoiceOver labels and reduced-motion support.
- No network requests, accounts, analytics, or external dependencies.

The included audio is synthesized noise shaped to resemble rain, not a field recording.

## Verification

The app builds successfully for the iOS Simulator SDK. Simulator services were unavailable in the build environment, so visual behavior, sound quality, lock-screen playback, and timer behavior still need a device smoke test.

Suggested device checks: play each texture; adjust volume; lock the phone and use playback controls; disconnect headphones; verify a sleep timer expires with the phone locked.

## Blue visual backgrounds and your media

Each option has a translucent overlay: Soft uses sky blue (30%), Steady uses cobalt blue (38%), and Heavy uses midnight blue (48%). A separate bottom gradient keeps controls legible. The procedural blue rain graphic remains visible until you add a video.

Place your clips anywhere inside the project's `Rainroom` source folder (for example, a new `Visuals` subfolder):

- `Soft-visual.mp4`
- `Steady-visual.mp4`
- `Heavy-visual.mp4`

MOV is also supported. Portrait 9:16 footage is ideal; other sizes fill the screen with cropping. Clips loop muted independently of the audio. Motion pauses when playback pauses, the app goes into the background, or Reduce Motion is enabled. The app does not download media.

Add recordings as `Soft-sound.m4a`, `Steady-sound.m4a`, and `Heavy-sound.m4a` inside the source folder. WAV, MP3, and AIFF are also supported. Custom recordings take priority over the synthesized WAV placeholders. Use one file per option, ideally edited for a seamless loop, then rebuild in Xcode.

The updated version compiles successfully. Video integration awaits your clips and a device playback check.

## Audio warning fix and IPA export

Audio-session activation, deactivation, sound loading, and playback now run on a serial background queue. UI updates return to the main queue, with request IDs preventing stale playback completions from overwriting newer actions. Version is 1.0, build 1. The iPhone Release build passes; runtime warnings must still be rechecked on a device.

Use this project's `Rainroom.xcodeproj`; previously extracted `Rainroom 2` or `Rainroom 3` folders do not contain these fixes.

For your own phone with a free Apple account, select your Personal Team under Signing & Capabilities, connect the phone, select it as destination, and Run. Free provisioning expires after seven days, requiring another install.

For a signed IPA with Apple Developer Program membership:
1. Select your signing team and a unique bundle identifier.
2. Choose an iOS device destination (not the simulator).
3. Choose Product > Archive.
4. In Organizer, select the archive and Distribute App.
5. Choose a registered-device distribution method such as Debugging or Release Testing (older Xcode versions use Development or Ad Hoc), follow signing prompts, and export.

The separate Rainroom-unsigned.ipa contains the Release iphoneos app in Payload/Rainroom.app. It has no signing identity or provisioning profile and cannot be installed directly. It is input for a compatible signing/sideloading tool; it is not an App Store or TestFlight upload.

Apple references:
- https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices
- https://developer.apple.com/support/compare-memberships/
