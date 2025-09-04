# flutter_ivs_stage

A comprehensive Flutter plugin for Amazon IVS (Interactive Video Service) Stages with complete iOS implementation. This plugin provides real-time video communication capabilities with multi-participant support, broadcasting, and **flexible UI options**.

## Features

### Core Functionality
- ✅ **Multi-participant video calls** (up to 12 participants)  
- ✅ **Real-time audio/video streaming** with Amazon IVS
- ✅ **Broadcasting capability** to external RTMP endpoints
- ✅ **Dynamic participant management** with join/leave events
- ✅ **Audio/video mute controls** for local user
- ✅ **Audio-only mode** for bandwidth optimization
- ✅ **Video mirroring support** for local and remote streams
- ✅ **Permission management** for camera and microphone access
- ✅ **Real-time streaming events** for all participant actions
- 🎨 **Flexible UI** - Use built-in widgets or build completely custom interfaces

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

1. Add required permissions to `ios/Runner/Info.plist`:

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

2. Run `cd ios && pod install`

## Usage Options

This package provides **two approaches** for implementation:

### 🚀 Option 1: Quick Start with Built-in StageView

For rapid development, use the pre-built `StageView` widget that includes all UI components:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_ivs_stage/flutter_ivs_stage.dart';

class QuickStageScreen extends StatelessWidget {
  final String stageToken;
  
  const QuickStageScreen({Key? key, required this.stageToken}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StageView(
        initialToken: stageToken,
        streamKey: 'your-stream-key',      // Optional: for broadcasting
        streamUrl: 'your-rtmp-url',        // Optional: for broadcasting  
        showControls: true,                // Show built-in controls
        backgroundColor: Colors.black,
        aspectRatio: 16 / 9,
      ),
    );
  }
}
```

**Built-in Layout:**
```
┌─────────────────────────────────────┐
│        Currently Viewing            │
│      (Top Center - Main View)       │
│    Selected Participant Stream      │
└─────────────────────────────────────┘

┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐
│U2 │  │U3 │  │U4 │  │U5 │  │U6 │  ...
└───┘  └───┘  └───┘  └───┘  └───┘
(Bottom Participant List)
```

### 🎨 Option 2: Custom UI with Core APIs

For complete control over the UI, use the core APIs and individual widgets:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_ivs_stage/flutter_ivs_stage.dart';

class CustomStageScreen extends StatefulWidget {
  @override
  _CustomStageScreenState createState() => _CustomStageScreenState();
}

class _CustomStageScreenState extends State<CustomStageScreen> {
  List<StageParticipant> _participants = [];
  StageConnectionState _connectionState = StageConnectionState.disconnected;
  bool _isLocalAudioMuted = false;
  bool _isLocalVideoMuted = false;
  bool _isBroadcasting = false;
  String? _selectedParticipantId;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _requestPermissions();
  }

  void _setupListeners() {
    // Listen to real-time participant changes
    FlutterIvsStage.participantsStream.listen((participants) {
      setState(() {
        _participants = participants;
      });
    });

    // Listen to connection state changes
    FlutterIvsStage.connectionStateStream.listen((state) {
      setState(() {
        _connectionState = state;
      });
    });

    // Listen to mute state changes
    FlutterIvsStage.localAudioMutedStream.listen((muted) {
      setState(() {
        _isLocalAudioMuted = muted;
      });
    });

    FlutterIvsStage.localVideoMutedStream.listen((muted) {
      setState(() {
        _isLocalVideoMuted = muted;
      });
    });

    // Listen to broadcasting state
    FlutterIvsStage.broadcastingStream.listen((broadcasting) {
      setState(() {
        _isBroadcasting = broadcasting;
      });
    });

    // Listen to errors
    FlutterIvsStage.errorStream.listen((error) {
      _showError(error);
    });
  }

  Future<void> _requestPermissions() async {
    await FlutterIvsStage.requestPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Custom IVS Stage'),
        backgroundColor: Colors.black,
        actions: [
          // Connection status indicator
          Container(
            margin: EdgeInsets.only(right: 16),
            child: Chip(
              label: Text(
                _connectionState.toString().split('.').last.toUpperCase(),
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: _getConnectionColor(),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Main video area - your custom design
          Expanded(
            flex: 3,
            child: _buildMainVideoView(),
          ),
          
          // Custom controls
          _buildCustomControls(),
          
          // Participant grid/list - your custom layout
          _buildParticipantGrid(),
        ],
      ),
    );
  }

  Widget _buildMainVideoView() {
    final selectedParticipant = _getSelectedParticipant();

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: selectedParticipant != null
            ? Stack(
                children: [
                  // Use the ParticipantVideoView widget
                  ParticipantVideoView(
                    participant: selectedParticipant,
                    showControls: false,
                    showVideoPreview: true,
                  ),
                  
                  // Custom overlay with participant info
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        selectedParticipant.isLocal 
                            ? 'You' 
                            : 'Participant ${selectedParticipant.participantId}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      _connectionState == StageConnectionState.connected
                          ? 'No participants'
                          : 'Not connected',
                      style: TextStyle(color: Colors.grey, fontSize: 18),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCustomControls() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Join/Leave button
          _buildControlButton(
            icon: _connectionState == StageConnectionState.connected 
                ? Icons.call_end 
                : Icons.call,
            label: _connectionState == StageConnectionState.connected 
                ? 'Leave' 
                : 'Join',
            onPressed: _connectionState == StageConnectionState.connected
                ? FlutterIvsStage.leaveStage
                : _showJoinDialog,
            backgroundColor: _connectionState == StageConnectionState.connected 
                ? Colors.red 
                : Colors.green,
          ),
          
          // Audio control
          _buildControlButton(
            icon: _isLocalAudioMuted ? Icons.mic_off : Icons.mic,
            label: _isLocalAudioMuted ? 'Unmute' : 'Mute',
            onPressed: FlutterIvsStage.toggleLocalAudioMute,
            backgroundColor: _isLocalAudioMuted ? Colors.red : Colors.green,
            enabled: _connectionState == StageConnectionState.connected,
          ),
          
          // Video control
          _buildControlButton(
            icon: _isLocalVideoMuted ? Icons.videocam_off : Icons.videocam,
            label: _isLocalVideoMuted ? 'Video On' : 'Video Off',
            onPressed: FlutterIvsStage.toggleLocalVideoMute,
            backgroundColor: _isLocalVideoMuted ? Colors.red : Colors.green,
            enabled: _connectionState == StageConnectionState.connected,
          ),
          
          // Broadcasting control
          _buildControlButton(
            icon: _isBroadcasting ? Icons.stop_circle : Icons.radio_button_checked,
            label: _isBroadcasting ? 'Stop Cast' : 'Broadcast',
            onPressed: FlutterIvsStage.toggleBroadcasting,
            backgroundColor: _isBroadcasting ? Colors.orange : Colors.purple,
            enabled: _connectionState == StageConnectionState.connected,
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantGrid() {
    if (_participants.length <= 1) return SizedBox.shrink();

    // Create your own custom grid/list layout
    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: _participants.length,
        itemBuilder: (context, index) {
          final participant = _participants[index];
          final isSelected = participant.participantId == _selectedParticipantId;
          
          // Skip the currently selected participant in the list
          if (isSelected) return SizedBox.shrink();
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedParticipantId = participant.participantId;
              });
              // Refresh video views after switching
              FlutterIvsStage.refreshVideoPreviews();
            },
            child: Container(
              width: 90,
              margin: EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.blue.withOpacity(0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ParticipantVideoView(
                  participant: participant,
                  showControls: false,
                  isCompact: true,
                  showVideoPreview: false, // Show placeholders in the list
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? backgroundColor,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.blue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  StageParticipant? _getSelectedParticipant() {
    if (_participants.isEmpty) return null;
    
    return _participants.firstWhere(
      (p) => p.participantId == _selectedParticipantId,
      orElse: () => _participants.first,
    );
  }

  Color _getConnectionColor() {
    switch (_connectionState) {
      case StageConnectionState.connected:
        return Colors.green;
      case StageConnectionState.connecting:
        return Colors.orange;
      case StageConnectionState.disconnected:
        return Colors.red;
    }
  }

  void _showJoinDialog() {
    // Use the built-in JoinStageWidget or create your own
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join Stage'),
        content: JoinStageWidget(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showError(StageError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${error.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    FlutterIvsStage.dispose();
    super.dispose();
  }
}
```

## Core APIs Reference

### Stage Management
```dart
// Join/Leave stage
await FlutterIvsStage.joinStage('your-stage-token');
await FlutterIvsStage.leaveStage();

// Permission handling
bool granted = await FlutterIvsStage.requestPermissions();
bool hasPermissions = await FlutterIvsStage.checkPermissions();
```

### Audio/Video Controls
```dart
// Toggle local controls
await FlutterIvsStage.toggleLocalAudioMute();
await FlutterIvsStage.toggleLocalVideoMute();

// Participant-specific controls
await FlutterIvsStage.toggleAudioOnlySubscribe('participant-id');

// Video mirroring (great for front cameras)
await FlutterIvsStage.setVideoMirroring(
  localVideo: true,   // Mirror your own camera
  remoteVideo: false, // Don't mirror others
);

// Refresh video streams (useful when switching views)
await FlutterIvsStage.refreshVideoPreviews();
```

### Broadcasting
```dart
// Set up broadcasting to RTMP
bool success = await FlutterIvsStage.setBroadcastAuth(
  'rtmp://your-endpoint.com/live',
  'your-stream-key',
);

// Start/stop broadcasting
await FlutterIvsStage.toggleBroadcasting();
```

## Real-time Streams

All state changes are available as streams for reactive UI updates:

```dart
// Participant management
FlutterIvsStage.participantsStream.listen((List<StageParticipant> participants) {
  // Update UI when participants join/leave
  print('Participants: ${participants.length}');
});

// Connection state
FlutterIvsStage.connectionStateStream.listen((StageConnectionState state) {
  // disconnected, connecting, connected
  print('Connection: $state');
});

// Audio/Video states
FlutterIvsStage.localAudioMutedStream.listen((bool muted) {
  print('Audio muted: $muted');
});

FlutterIvsStage.localVideoMutedStream.listen((bool muted) {
  print('Video muted: $muted');
});

// Broadcasting state
FlutterIvsStage.broadcastingStream.listen((bool broadcasting) {
  print('Broadcasting: $broadcasting');
});

// Error handling
FlutterIvsStage.errorStream.listen((StageError error) {
  print('Error: ${error.message}');
});
```

## Individual Widgets for Custom UIs

### ParticipantVideoView
Display individual participant video streams with customizable options:

```dart
ParticipantVideoView(
  participant: participant,
  showControls: true,      // Show participant-specific controls
  isCompact: false,        // Compact mode for thumbnails
  showVideoPreview: true,  // Show actual video or placeholder
)
```

### JoinStageWidget  
Pre-built stage joining interface:

```dart
JoinStageWidget(
  initialToken: 'optional-token',
)
```

### BroadcastControlsWidget
Broadcasting controls interface:

```dart
BroadcastControlsWidget(
  isBroadcasting: false,
  streamKey: 'your-stream-key',
  streamUrl: 'your-rtmp-url',
)
```

## Data Models

### StageParticipant
```dart
class StageParticipant {
  final bool isLocal;
  final String? participantId;
  final StageStream? audioStream;
  final StageStream? videoStream;
  final String publishState;    // notPublished, attemptingPublish, published
  final String subscribeState;  // notSubscribed, attemptingSubscribe, subscribed
  final bool isAudioOnly;
  // ...
}
```

### StageConnectionState
```dart
enum StageConnectionState {
  disconnected,
  connecting,  
  connected,
}
```

### StageError
```dart
class StageError {
  final String code;
  final String message;
  final String? source;
}
```

## Advanced Features

### Video Mirroring
Perfect for creating natural camera experiences:

```dart
// Mirror local camera (selfie mode)
FlutterIvsStage.setVideoMirroring(localVideo: true, remoteVideo: false);

// Mirror all videos
FlutterIvsStage.setVideoMirroring(localVideo: true, remoteVideo: true);
```

### Audio-Only Mode  
Reduce bandwidth by switching participants to audio-only:

```dart
FlutterIvsStage.toggleAudioOnlySubscribe('participant-id');
```

### Broadcasting Integration
Stream your stage to external platforms:

```dart
// Setup
await FlutterIvsStage.setBroadcastAuth('rtmp://endpoint', 'stream-key');

// Go live
await FlutterIvsStage.toggleBroadcasting();

// Listen to state
FlutterIvsStage.broadcastingStream.listen((broadcasting) {
  print('Live: $broadcasting');
});
```

## Example Projects

Check out the `/example` folder for complete implementations:

1. **Built-in StageView Example** - Quick implementation using `StageView`
2. **Custom UI Example** - Advanced custom interface using core APIs
3. **Broadcasting Example** - Integration with RTMP streaming
4. **Permission Handling** - Proper permission management

## Best Practices

### Performance
- Use `isCompact: true` for participant thumbnails
- Set `showVideoPreview: false` for participant lists to show placeholders
- Call `refreshVideoPreviews()` after major UI changes

### UI/UX  
- Always show connection state to users
- Provide visual feedback for mute states
- Handle errors gracefully with user-friendly messages
- Use video mirroring for front-facing cameras

### Resource Management
- Call `dispose()` when leaving the stage screen
- Handle app lifecycle events (background/foreground)
- Monitor participant counts for optimal performance

## Troubleshooting

### Common Issues

1. **Black video screens**
   - Check camera permissions
   - Verify stage token validity
   - Try calling `refreshVideoPreviews()`

2. **Audio not working**
   - Check microphone permissions
   - Verify audio is not muted
   - Check device audio settings

3. **Connection issues**
   - Verify internet connectivity
   - Check stage token expiration
   - Monitor `connectionStateStream` for state changes

### Debug Logging
Enable debug logging to troubleshoot issues:

```dart
FlutterIvsStage.errorStream.listen((error) {
  print('IVS Error: ${error.code} - ${error.message}');
});
```

## Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) for details on:

- Setting up development environment
- Code style and conventions  
- Submitting pull requests
- Reporting issues

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Need Help?

- 📚 **Documentation**: Check the `/example` folder for working implementations
- 🐛 **Issues**: Report bugs on our [GitHub Issues](https://github.com/SunilDevX/flutter_ivs_stage/issues) page
- 💬 **Discussions**: Join discussions in our [GitHub Discussions](https://github.com/SunilDevX/flutter_ivs_stage/discussions)
- 📧 **Support**: Contact us for enterprise support options

