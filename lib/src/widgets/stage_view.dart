import 'dart:developer';

import 'package:flutter/material.dart';

import '../../flutter_ivs_stage.dart';

/// A widget that displays the current stage with participants
class StageView extends StatefulWidget {
  final String? initialToken;
  final String? streamKey;
  final String? streamUrl;
  final bool showControls;
  final EdgeInsets padding;
  final Color backgroundColor;
  final double aspectRatio;

  const StageView({
    super.key,
    this.initialToken,
    this.streamKey,
    this.streamUrl,
    this.showControls = true,
    this.padding = const EdgeInsets.all(16.0),
    this.backgroundColor = Colors.black,
    this.aspectRatio = 16 / 9,
  });

  @override
  State<StageView> createState() => _StageViewState();
}

class _StageViewState extends State<StageView> {
  String? _selectedParticipantId;
  List<StageParticipant> _participants = [];
  StageConnectionState _connectionState = StageConnectionState.disconnected;
  bool _isLocalAudioMuted = false;
  bool _isLocalVideoMuted = false;
  bool _isBroadcasting = false;
  bool _mirrorLocalVideo = false;
  bool _mirrorRemoteVideo = false;

  // Camera preview state
  bool _isPreviewActive = false;
  String _currentCameraType = 'front';
  final String _aspectMode = 'fill';

  @override
  void initState() {
    super.initState();
    _setupStreams();
    _checkPermissions();
    _initializeCameraPreview();
  }

  /// Initialize camera preview when not connected to stage
  Future<void> _initializeCameraPreview() async {
    if (_connectionState == StageConnectionState.disconnected) {
      try {
        await FlutterIvsStage.initPreview(
          cameraType: _currentCameraType,
          aspectMode: _aspectMode,
        );
        setState(() {
          _isPreviewActive = true;
        });
        log('Camera preview initialized successfully');
      } catch (e) {
        log('Failed to initialize camera preview: $e');
        setState(() {
          _isPreviewActive = false;
        });
      }
    }
  }

  /// Toggle camera between front and back
  Future<void> _toggleCamera() async {
    final newCameraType = _currentCameraType == 'front' ? 'back' : 'front';
    try {
      await FlutterIvsStage.toggleCamera(newCameraType);
      setState(() {
        _currentCameraType = newCameraType;
      });
      log('Camera toggled to: $newCameraType');
    } catch (e) {
      log('Failed to toggle camera: $e');
    }
  }

  /// Stop camera preview
  Future<void> _stopPreview() async {
    if (_isPreviewActive) {
      try {
        await FlutterIvsStage.stopPreview();
        setState(() {
          _isPreviewActive = false;
        });
        log('Camera preview stopped');
      } catch (e) {
        log('Failed to stop camera preview: $e');
      }
    }
  }

  /// Safely update participant selection, preserving current selection when possible
  void _updateParticipantSelection(List<StageParticipant> newParticipants) {
    // Only clear selection if the selected participant actually left
    if (_selectedParticipantId != null &&
        !newParticipants.any(
          (p) => p.participantId == _selectedParticipantId,
        )) {
      _selectedParticipantId = null;
    }
  }

  void _setupStreams() {
    // Listen to participants stream
    FlutterIvsStage.participantsStream.listen((participants) {
      setState(() {
        _participants = participants;
        _updateParticipantSelection(participants);
      });
    });

    // Listen to connection state
    FlutterIvsStage.connectionStateStream.listen((state) {
      setState(() {
        _connectionState = state;
      });

      // Handle camera preview based on connection state
      if (state == StageConnectionState.connected) {
        // Stop preview when joining stage
        _stopPreview();
        // Apply default mirroring when connected
        _updateMirroring();
      } else if (state == StageConnectionState.disconnected) {
        // Restart preview when disconnected
        _initializeCameraPreview();
      }
    });

    // Listen to audio mute state
    FlutterIvsStage.localAudioMutedStream.listen((muted) {
      setState(() {
        _isLocalAudioMuted = muted;
      });
    });

    // Listen to video mute state
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
      _showErrorDialog(error);
    });
  }

  Future<void> _checkPermissions() async {
    final hasPermissions = await FlutterIvsStage.checkPermissions();
    if (!hasPermissions) {
      await FlutterIvsStage.requestPermissions();
    }
  }

  void _showErrorDialog(StageError error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(error.title),
        content: Text(error.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      padding: widget.padding,
      child: Column(
        children: [
          // Main viewing area
          Expanded(flex: 2, child: _buildMainViewArea()),
          const SizedBox(height: 16),
          // Participant list
          if (_participants.length > 1)
            SizedBox(height: 120, child: _buildParticipantList()),
          const SizedBox(height: 16),
          // Controls
          if (widget.showControls) _buildControls(),
        ],
      ),
    );
  }

  Widget _buildMainViewArea() {
    // If preview is active and no participants, show preview participant
    StageParticipant selectedParticipant;

    if (_isPreviewActive && _participants.isEmpty) {
      selectedParticipant = _createPreviewParticipant();
    } else {
      selectedParticipant = _participants.firstWhere(
        (p) => p.participantId == _selectedParticipantId,
        orElse: () => _participants.isNotEmpty
            ? _participants.first
            : _createEmptyParticipant(),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Stack(
        children: [
          // Video view
          Center(
            child: AspectRatio(
              aspectRatio: widget.aspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: selectedParticipant.participantId != null
                      ? ParticipantVideoView(
                          key: ValueKey(selectedParticipant.participantId),
                          participant: selectedParticipant,
                          showControls: false,
                          showVideoPreview: true,
                        )
                      : const Center(
                          key: ValueKey('empty_state'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.video_call_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Currently Viewing',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
          // Participant info overlay
          if (selectedParticipant.participantId != null)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  selectedParticipant.isLocal
                      ? 'You (${selectedParticipant.participantId ?? 'Disconnected'})'
                      : selectedParticipant.participantId ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantList() {
    final otherParticipants = _participants.where((p) {
      if (_selectedParticipantId == null) {
        return !p.isLocal;
      }
      return p.participantId != _selectedParticipantId;
    }).toList();

    if (otherParticipants.isEmpty) {
      return Container();
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: otherParticipants.length,
      itemBuilder: (context, index) {
        final participant = otherParticipants[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedParticipantId = participant.participantId;
              });
              // Small delay to let the UI update, then refresh the main view
              Future.delayed(const Duration(milliseconds: 100), () {
                FlutterIvsStage.refreshVideoPreviews();
              });
            },
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[600]!, width: 1),
              ),
              child: ParticipantVideoView(
                participant: participant,
                showControls: true,
                isCompact: true,
                showVideoPreview:
                    false, // Participant boxes don't show video preview
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Connection controls
          if (_connectionState == StageConnectionState.disconnected)
            _buildJoinControls()
          else
            _buildStageControls(),
          const SizedBox(height: 16),
          // Video mirroring controls
          if (_connectionState == StageConnectionState.connected)
            _buildMirroringControls(),
          const SizedBox(height: 16),
          // Broadcasting controls
          _buildBroadcastControls(),
        ],
      ),
    );
  }

  Widget _buildJoinControls() {
    return Column(
      children: [
        // Camera preview controls (when disconnected)
        if (_connectionState == StageConnectionState.disconnected)
          _buildPreviewControls(),
        const SizedBox(height: 16),
        // Join stage widget
        JoinStageWidget(initialToken: widget.initialToken),
      ],
    );
  }

  Widget _buildPreviewControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: _currentCameraType == 'front'
              ? Icons.camera_front
              : Icons.camera_rear,
          label: _currentCameraType == 'front' ? 'Front Camera' : 'Back Camera',
          onPressed: _toggleCamera,
          backgroundColor: Colors.blue,
        ),
        _buildControlButton(
          icon: Icons.flip_camera_ios,
          label: 'Flip Camera',
          onPressed: _toggleCamera,
          backgroundColor: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStageControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: _isLocalAudioMuted ? Icons.mic_off : Icons.mic,
          label: _isLocalAudioMuted ? 'Mic: Off' : 'Mic: On',
          onPressed: FlutterIvsStage.toggleLocalAudioMute,
          backgroundColor: _isLocalAudioMuted ? Colors.red : Colors.green,
        ),
        _buildControlButton(
          icon: _isLocalVideoMuted ? Icons.videocam_off : Icons.videocam,
          label: _isLocalVideoMuted ? 'Camera: Off' : 'Camera: On',
          onPressed: FlutterIvsStage.toggleLocalVideoMute,
          backgroundColor: _isLocalVideoMuted ? Colors.red : Colors.green,
        ),
        _buildControlButton(
          icon: Icons.call_end,
          label: 'Leave',
          onPressed: FlutterIvsStage.leaveStage,
          backgroundColor: Colors.red,
        ),
      ],
    );
  }

  Widget _buildMirroringControls() {
    return Column(
      children: [
        Text(
          'Video Mirroring',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMirrorToggle(
              label: 'Local Video',
              value: _mirrorLocalVideo,
              onChanged: (value) {
                setState(() {
                  _mirrorLocalVideo = value;
                });
                _updateMirroring();
              },
            ),
            _buildMirrorToggle(
              label: 'Remote Video',
              value: _mirrorRemoteVideo,
              onChanged: (value) {
                setState(() {
                  _mirrorRemoteVideo = value;
                });
                _updateMirroring();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMirrorToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.blue,
        ),
      ],
    );
  }

  void _updateMirroring() {
    FlutterIvsStage.setVideoMirroring(
      localVideo: _mirrorLocalVideo,
      remoteVideo: _mirrorRemoteVideo,
    );
  }

  Widget _buildBroadcastControls() {
    return BroadcastControlsWidget(
      isBroadcasting: _isBroadcasting,
      streamKey: widget.streamKey,
      streamUrl: widget.streamUrl,
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Creates a preview participant for showing camera preview before joining stage
  StageParticipant _createPreviewParticipant() {
    return StageParticipant(
      isLocal: true,
      participantId: 'preview_local_user',
      publishState: StageParticipantPublishState.published,
      subscribeState: StageParticipantSubscribeState.subscribed,
      streams: [
        StageStream(
          deviceId: 'preview_camera_$_currentCameraType',
          type: StageStreamType.video,
          isMuted: false,
        ),
        const StageStream(
          deviceId: 'preview_microphone',
          type: StageStreamType.audio,
          isMuted: true, // Start with audio muted in preview
        ),
      ],
      broadcastSlotName: 'preview',
    );
  }

  StageParticipant _createEmptyParticipant() {
    return const StageParticipant(
      isLocal: false,
      participantId: null,
      publishState: StageParticipantPublishState.notPublished,
      subscribeState: StageParticipantSubscribeState.notSubscribed,
      streams: [],
      broadcastSlotName: '',
    );
  }

  @override
  void dispose() {
    _stopPreview();
    FlutterIvsStage.dispose();
    super.dispose();
  }
}
