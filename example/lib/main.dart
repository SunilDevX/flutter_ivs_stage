import 'package:flutter/material.dart';
import 'package:flutter_ivs_stage/flutter_ivs_stage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter IVS Stage Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const DemoSelectionPage(),
    );
  }
}

class DemoSelectionPage extends StatelessWidget {
  const DemoSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter IVS Stage Demo'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose Implementation Approach:',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Built-in StageView Option
            Card(
              elevation: 4,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BuiltInStageViewDemo(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.rocket_launch, size: 48, color: Colors.blue),
                      const SizedBox(height: 12),
                      const Text(
                        '🚀 Built-in StageView',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Quick start with pre-built UI components.\nIncludes all controls and layouts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Custom UI Option
            Card(
              elevation: 4,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CustomUIDemo()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.palette, size: 48, color: Colors.purple),
                      const SizedBox(height: 12),
                      const Text(
                        '🎨 Custom UI',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Build your own interface using core APIs.\nComplete control over design and behavior.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Camera Preview Option
            Card(
              elevation: 4,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraPreviewDemo(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.camera_alt, size: 48, color: Colors.orange),
                      const SizedBox(height: 12),
                      const Text(
                        '📹 Camera Preview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Preview camera before joining stage.\nToggle front/back camera with controls.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(),

            const Text(
              'Both approaches demonstrate:\n'
              '• Multi-participant video calls\n'
              '• Audio/video controls\n'
              '• Broadcasting capabilities\n'
              '• Real-time participant management',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Built-in StageView Example
class BuiltInStageViewDemo extends StatelessWidget {
  const BuiltInStageViewDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Built-in StageView Demo'),
        backgroundColor: Colors.blue,
      ),
      body: const StageView(
        // You can provide initial token here or use the built-in join dialog
        initialToken: null,
        streamKey: 'your-stream-key',
        streamUrl: 'your-rtmp-url',
        showControls: true,
        backgroundColor: Colors.black,
        aspectRatio: 16 / 9,
      ),
    );
  }
}

// Custom UI Example
class CustomUIDemo extends StatefulWidget {
  const CustomUIDemo({super.key});

  @override
  State<CustomUIDemo> createState() => _CustomUIDemoState();
}

class _CustomUIDemoState extends State<CustomUIDemo> {
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
        title: const Text('Custom UI Demo'),
        backgroundColor: Colors.purple,
        actions: [
          // Connection status indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Chip(
              label: Text(
                _connectionState.toString().split('.').last.toUpperCase(),
                style: const TextStyle(
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
          // Main video area
          Expanded(flex: 3, child: _buildMainVideoView()),

          // Custom controls
          _buildCustomControls(),

          // Participant list
          _buildParticipantList(),
        ],
      ),
    );
  }

  Widget _buildMainVideoView() {
    final selectedParticipant = _getSelectedParticipant();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple, width: 2),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        selectedParticipant.isLocal
                            ? 'You'
                            : 'Participant ${selectedParticipant.participantId}',
                        style: const TextStyle(
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
                    const Icon(Icons.people, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      _connectionState == StageConnectionState.connected
                          ? 'No participants'
                          : 'Not connected',
                      style: const TextStyle(color: Colors.grey, fontSize: 18),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCustomControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
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

          // Mirror control
          _buildControlButton(
            icon: Icons.flip_camera_ios,
            label: 'Mirror',
            onPressed: () => _toggleMirroring(),
            backgroundColor: Colors.blue,
            enabled: _connectionState == StageConnectionState.connected,
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantList() {
    if (_participants.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _participants.length,
        itemBuilder: (context, index) {
          final participant = _participants[index];
          final isSelected =
              participant.participantId == _selectedParticipantId;

          // Skip the currently selected participant in the list
          if (isSelected) return const SizedBox.shrink();

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
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.purple.withOpacity(0.5),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
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
    // Use the built-in JoinStageWidget
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Stage'),
        content: const JoinStageWidget(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toggleMirroring() {
    // Demo mirroring functionality
    FlutterIvsStage.setVideoMirroring(localVideo: true, remoteVideo: false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video mirroring enabled for local camera'),
        duration: Duration(seconds: 2),
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

// Camera Preview Demo
class CameraPreviewDemo extends StatefulWidget {
  const CameraPreviewDemo({super.key});

  @override
  State<CameraPreviewDemo> createState() => _CameraPreviewDemoState();
}

class _CameraPreviewDemoState extends State<CameraPreviewDemo> {
  String _currentCameraType = 'front';
  String _statusMessage = 'Camera preview ready';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Preview Demo'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Info section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📹 Camera Preview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This demonstrates the camera preview functionality that allows users to see their camera feed before joining a stage.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current Camera: $_currentCameraType',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.orange[700],
                    ),
                  ),
                  Text(
                    'Status: $_statusMessage',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Camera preview widget
            Expanded(
              child: CameraPreviewWidget(
                initialCameraType: _currentCameraType,
                aspectMode: 'fill',
                showControls: true,
                backgroundColor: Colors.grey[900]!,
                borderRadius: 16,
                onCameraChanged: (cameraType) {
                  setState(() {
                    _currentCameraType = cameraType;
                    _statusMessage = 'Switched to $cameraType camera';
                  });
                },
                onError: (error) {
                  setState(() {
                    _statusMessage = 'Error: $error';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Camera Error: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BuiltInStageViewDemo(),
                      ),
                    );
                  },
                  icon: Icon(Icons.video_call),
                  label: Text('Join Stage'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CustomUIDemo(),
                      ),
                    );
                  },
                  icon: Icon(Icons.palette),
                  label: Text('Custom UI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Feature highlights
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Camera Preview Features:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Preview camera before joining stage\n'
                    '• Toggle between front and back cameras\n'
                    '• Automatic mirroring for front camera\n'
                    '• Error handling and retry functionality\n'
                    '• Customizable aspect modes (fill/fit)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
