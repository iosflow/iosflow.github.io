# focusFlow · Rainroom implementation

The focusFlow Xcode project now runs the supplied **Rainroom / ASMRainStorm** implementation. Its screen, branding, media, timer behavior, audio, and Health integration are preserved. The source has been split into the folder structure used by the professor's Starter project.

## Source layout

```
focusFlow/
├── App/                   # SwiftUI entry point and UIKit app/scene delegates
├── Models/                # RainPalette and Live Activity attributes
├── View Models/           # RainPlayer: playback, timers, and Pomodoro state
├── Views/                 # ContentView and RainBackground
│   └── Components/        # Header, sleep timer, glow border, looping video
├── Services/              # Audio engine, HealthKit, shortcuts, activity cleanup
├── Resources/
│   ├── Assets/            # Original app icon and launch artwork
│   ├── Audio/             # Original audio/video, including compressed recordings
│   └── LaunchScreen.storyboard
└── focusFlow.entitlements
focusFlowLiveActivity/      # Original lock-screen / Dynamic Island widget extension
Configuration/             # App and extension Info.plists
focusFlowTests/             # Shortcut routing and bundled-media checks
focusFlowUITests/           # Rain controls and sleep-timer smoke test
```

## Original Rainroom behavior

- Starts a 60-minute rain session on launch, choosing a random rain texture.
- Controls start hidden. Swipe vertically to reveal or hide them.
- Soft, Steady, Heavy, and Thunderstorm recordings, volume slider, and looping rain video with the original blue overlays.
- Pomodoro runs two 55-minute focus / 5-minute beach-break cycles. Tapping the active Pomodoro button skips to the next phase. Original bells and completion sound are included.
- Sleep timer presets from 1 minute to 8 hours, plus Off; timer glow and countdown match Rainroom.
- Timer time is wall-clock time, including paused playback. Health logs timer time in minute checkpoints, including break timers, exactly as the supplied Rainroom implementation does. Health permission is requested by the original code; there is no separate mindful-session toggle or journal.
- Original Home Screen shortcuts, background audio, interruption handling, Reduce Motion behavior, launch screen, app icon, Live Activities, and Dynamic Island extension are included.

The previous green Pomodoro screen, progress journal, configurable settings screen, and its timer/persistence services have been removed from the active target. Existing history files from that implementation are not deleted, but Rainroom does not read them.

## Run

Open **focusFlow.xcodeproj**, select **focusFlow**, and run on an iPhone simulator or device (iOS 17+). The display name remains **ASMRainStorm** to match Rainroom. The main bundle identifier remains `iosflow.focusFlow`; its extension uses `iosflow.focusFlow.RainroomLiveActivity`.

The project uses standard `project.pbxproj` configuration to include the embedded widget extension and both test targets. If Xcode has the project open during migration, close and reopen it to refresh the navigator. Choose a development team for the app and extension before installing on a device; HealthKit must be supported by the signing profile.

## Scope and verification

This is a structural migration, not a redesign or timer-behavior rewrite. `Rainroom 4/` and `Starter/` remain unchanged as references. Audio/video are copied byte-for-byte from the current Rainroom reference, including the smaller media files. The SwiftUI entry-point type and shortcut bundle prefix are adjusted for the focusFlow target; helper types are made internal where separate files need access.

Validation passed on the iPhone 17 Simulator: the app and embedded extension build, two unit tests pass (shortcut routing and bundled media), and the UI test passes (reveal controls, select Heavy rain, open the sleep timer, and turn it Off). The migration comparison confirmed RainPlayer, RainAudioEngine, and MindfulnessHealthStore matched Rainroom before preview support was added; all 12 media files match byte-for-byte. The simulator test build is unsigned, so Health writes were not validated. Physical-device checks are still needed for Health writes, Home Screen quick actions, lock-screen activity presentation, background playback, timer transitions, and audio quality after compression. Rainroom's original implementation silently handles Health write failures and does not persist timer state across termination; those behaviors are retained here.

## Xcode previews

Open `focusFlow/Views/ContentView.swift` and show the Canvas (Option-Command-Return). The **Rain controls** preview shows the controls; **Immersive rain** shows the initial hidden-controls layout. `ContentView` owns the screen's `RainPlayer` and is the app's main view. Preview instances use a deterministic Heavy-rain fixture and skip automatic playback, timers, Health requests, shortcut observers, and saved-preference writes. Normal app launches retain Rainroom behavior.
