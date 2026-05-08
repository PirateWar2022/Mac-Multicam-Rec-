# MultiCam Recorder

A native macOS app for simultaneous recording from up to 5 cameras.

## Requirements
- macOS 13.0 Ventura or later
- Xcode 15+
- One or more connected cameras (USB, built-in, capture cards, iPhone via Continuity Camera)

## Setup

1. Open `MultiCamRecorder.xcodeproj` in Xcode
2. In the project settings, change the **Team** under Signing & Capabilities to your Apple ID
3. Change `PRODUCT_BUNDLE_IDENTIFIER` in Build Settings if needed
4. Press ⌘R to build and run

## Features

- **5-camera live preview grid** — 3 cameras on top, 2 on bottom
- **Simultaneous recording** — all cameras start/stop in sync with one click (or ⌘R)
- **Per-camera device picker** — reassign any slot to any connected camera at any time
- **Auto-detection** — cameras are assigned automatically on launch
- **H.264 + AAC** output at ~8 Mbps video / 128 kbps audio per camera
- **Named output files** — `Camera1_2024-01-15T10-30-00Z.mov` etc. in `~/Movies/MultiCamRecorder/`
- **Configurable output folder** — click the folder icon in the title bar
- **Live duration timer** while recording

## Supported camera types

| Type | Notes |
|------|-------|
| Built-in FaceTime HD | Works automatically |
| USB webcams | Plug in before launching |
| HDMI capture cards (Elgato, AVerMedia…) | Appear as USB cameras |
| iPhone Continuity Camera | Enable in iOS Settings → General → AirPlay & Handoff |
| NDI cameras | Require NDI Tools virtual camera driver |

## File output

Each camera writes its own `.mov` file:
```
~/Movies/MultiCamRecorder/
  Camera1_2024-01-15T10-30-00Z.mov
  Camera2_2024-01-15T10-30-00Z.mov
  Camera3_2024-01-15T10-30-00Z.mov
  Camera4_2024-01-15T10-30-00Z.mov
  Camera5_2024-01-15T10-30-00Z.mov
```

Files use the same start timestamp, making it easy to sync in Final Cut Pro, DaVinci Resolve, or Premiere.

## Syncing footage in an editor

All cameras start writing at the same wall-clock instant (within ~100 ms). For frame-accurate sync:
- Use a clapper board / flash a light visible to all cameras at the start
- Or use an external timecode generator (e.g. Tentacle Sync)

## Customisation

| What to change | Where |
|---|---|
| Video bitrate | `CameraSession.swift` → `AVVideoAverageBitRateKey` |
| Codec (H.264 / HEVC) | `CameraSession.swift` → `AVVideoCodecKey` |
| Output format (.mov / .mp4) | `CameraSession.swift` → `AVAssetWriter(fileType:)` |
| Number of cameras (1–8) | `RecordingCoordinator.swift` → `cameraCount` + update grid in `ContentView.swift` |

## Permissions

The app requests:
- **Camera** — to display live previews
- **Microphone** — to record audio on each track

Both are mandatory for recording. macOS will prompt on first launch.

## Troubleshooting

**Camera not appearing**
- Unplug and replug the USB camera
- Click the ↻ refresh button in the title bar

**"No signal" tile**
- The camera may already be in use by another app (Zoom, FaceTime, etc.)
- Quit the other app and press ↻

**Low frame rate**
- Lower the session preset in `CameraSession.swift`: `.high` → `.medium`
- Check CPU / disk write speed in Activity Monitor
