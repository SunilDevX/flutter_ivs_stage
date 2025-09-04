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

  @override
  void initState() {
    super.initState();
    _setupStreams();
    _checkPermissions();
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

      // Apply default mirroring when connected
      if (state == StageConnectionState.connected) {
        _updateMirroring();
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
    final selectedParticipant = _participants.firstWhere(
      (p) => p.participantId == _selectedParticipantId,
      orElse: () => _participants.isNotEmpty
          ? _participants.first
          : _createEmptyParticipant(),
    );

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
                  color: Colors.black.withOpacity(0.7),
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
    return JoinStageWidget(initialToken: widget.initialToken);
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
    FlutterIvsStage.dispose();
    super.dispose();
  }
}
