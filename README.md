# flutter_ivs_stage

A comprehensive Flutter plugin for Amazon IVS (Interactive Video Service) Stages with complete iOS implementation. This plugin provides real-time video communication capabilities with multi-participant support, broadcasting, and custom UI layouts.

## Features

### Core Functionality
- ✅ **Multi-participant video calls** (up to 12 participants)
- ✅ **Real-time audio/video streaming** with Amazon IVS
- ✅ **Broadcasting capability** to external RTMP endpoints
- ✅ **Dynamic participant management** with join/leave events
- ✅ **Audio/video mute controls** for local user
- ✅ **Audio-only mode** for bandwidth optimization
- ✅ **Background/foreground handling** with automatic quality adjustments
- ✅ **Permission management** for camera and microphone access
- ✅ **Real-time streaming events** for all participant actions

### Custom UI Layout
- 🎨 **Top Center Main View** - Currently viewing participant
- 🎨 **Bottom Horizontal List** - Other participants in compact boxes
- 🎨 **Tap to Switch** - Click any participant box to switch main view
- 🎨 **Visual Feedback** - Audio level visualization and mute states
- 🎨 **Responsive Design** - Adapts to different screen sizes

### Streaming Events
- 👤 **User joined/left** events
- 🔇 **Audio mute/unmute** events  
- 📹 **Video on/off** events
- 🔗 **Connection state** changes
- ❌ **Error handling** with detailed messages
- 📡 **Broadcasting state** updates

## Platform Support

| Platform | Supported |
|----------|-----------|
| iOS      | ✅        |
| Android  | ❌ (Coming Soon) |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_ivs_stage: ^1.0.0
```

### iOS Setup

1. Add the Amazon IVS SDK to your iOS project by updating `ios/Podfile`:

```ruby
platform :ios, '12.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  # Add Amazon IVS Broadcast SDK
  pod 'AmazonIVSBroadcast', '~> 1.15.0'
end
```

2. Add required permissions to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for audio calls</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

3. Run `cd ios && pod install`

## Usage

### Basic Implementation

```dart
import 'package:flutter/material.dart';
import 'package:flutter_ivs_stage/flutter_ivs_stage.dart';

class StageScreen extends StatelessWidget {
  final String stageToken;
  
  const StageScreen({Key? key, required this.stageToken}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StageView(
        initialToken: stageToken,
        showControls: true,
        backgroundColor: Colors.black,
        aspectRatio: 16 / 9,
      ),
    );
  }
}
```

## API Reference

### Methods

| Method | Description | Parameters |
|--------|-------------|------------|
| `joinStage(token)` | Join a stage with token | `String token` |
| `leaveStage()` | Leave current stage | - |
| `toggleLocalAudioMute()` | Toggle local audio mute | - |
| `toggleLocalVideoMute()` | Toggle local video mute | - |
| `toggleAudioOnlySubscribe(participantId)` | Toggle audio-only for participant | `String participantId` |
| `setBroadcastAuth(endpoint, streamKey)` | Set broadcast credentials | `String endpoint, String streamKey` |
| `toggleBroadcasting()` | Start/stop broadcasting | - |
| `requestPermissions()` | Request camera/mic permissions | - |
| `checkPermissions()` | Check permissions status | - |

### Streams

| Stream | Type | Description |
|--------|------|-------------|
| `participantsStream` | `Stream<List<StageParticipant>>` | All participants data |
| `connectionStateStream` | `Stream<StageConnectionState>` | Stage connection state |
| `localAudioMutedStream` | `Stream<bool>` | Local audio mute state |
| `localVideoMutedStream` | `Stream<bool>` | Local video mute state |
| `broadcastingStream` | `Stream<bool>` | Broadcasting state |
| `errorStream` | `Stream<StageError>` | Error events |

## Layout Design

The plugin implements your requested custom layout:

```
┌─────────────────────────────────────┐
│        Currently Viewing            │
│      (Top Center - Main View)       │
│                                     │
│    Selected Participant Stream      │
│                                     │
└─────────────────────────────────────┘

┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐
│U2 │  │U3 │  │U4 │  │U5 │  │U6 │  ...
└───┘  └───┘  └───┘  └───┘  └───┘
(Bottom Horizontal List - Other Participants)
```

**Interaction:**
- Tap any participant box to switch it to the main viewing area
- The selected participant is hidden from the bottom list
- Audio-only toggle available for remote participants
- Visual feedback for audio levels and mute states

