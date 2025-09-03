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

  @override
  void initState() {
    super.initState();
    _setupStreams();
    _checkPermissions();
  }

  void _setupStreams() {
    // Listen to participants stream
    FlutterIvsStage.participantsStream.listen((participants) {
      setState(() {
        _participants = participants;
        // Auto-select the first remote participant if no one is selected
        if (_selectedParticipantId == null && participants.length > 1) {
          final remoteParticipant = participants.firstWhere(
            (p) => p.isLocal == false,
            orElse: () => participants.first,
          );
          _selectedParticipantId = remoteParticipant.participantId;
        }
        // Clear selection if participant left
        if (_selectedParticipantId != null &&
            !participants.any(
              (p) => p.participantId == _selectedParticipantId,
            )) {
          _selectedParticipantId = null;
        }
      });
    });

    // Listen to connection state
    FlutterIvsStage.connectionStateStream.listen((state) {
      setState(() {
        _connectionState = state;
      });
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
                child: selectedParticipant.participantId != null
                    ? ParticipantVideoView(
                        participant: selectedParticipant,
                        showControls: false,
                      )
                    : const Center(
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
    final otherParticipants = _participants
        .where((p) => p.participantId != _selectedParticipantId)
        .toList();

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
