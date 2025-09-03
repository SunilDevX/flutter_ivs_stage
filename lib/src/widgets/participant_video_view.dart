import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../flutter_ivs_stage.dart';

/// Widget for displaying a participant's video stream
class ParticipantVideoView extends StatelessWidget {
  final StageParticipant participant;
  final bool showControls;
  final bool isCompact;

  const ParticipantVideoView({
    super.key,
    required this.participant,
    this.showControls = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getBorderColor(), width: _getBorderWidth()),
      ),
      child: Stack(
        children: [
          // Video content
          _buildVideoContent(),

          // Overlays
          if (!isCompact) ...[
            // Participant info
            _buildParticipantInfo(),

            // State indicators
            _buildStateIndicators(),

            // Audio only toggle (for remote participants)
            if (showControls && !participant.isLocal)
              _buildAudioOnlyToggle(context),
          ] else ...[
            // Compact view overlays
            _buildCompactOverlay(),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoContent() {
    final videoStream = participant.videoStream;
    final isVideoMuted = videoStream?.isMuted ?? true;

    if (isVideoMuted || participant.isAudioOnly) {
      // Show avatar placeholder
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: isCompact ? 20 : 40,
              backgroundColor: Colors.grey[600],
              child: Icon(
                Icons.person,
                size: isCompact ? 20 : 40,
                color: Colors.white,
              ),
            ),
            if (!isCompact) ...[
              const SizedBox(height: 8),
              Text(
                isVideoMuted ? 'Camera Off' : 'Audio Only',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ],
        ),
      );
    }

    // Show actual video stream using platform view
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: UiKitView(
        viewType: 'ivs_video_view',
        creationParams: {
          'participantId': participant.participantId,
          'isLocal': participant.isLocal,
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }

  Widget _buildParticipantInfo() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          participant.isLocal
              ? 'You (${participant.participantId ?? 'Disconnected'})'
              : participant.participantId ?? 'Unknown',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStateIndicators() {
    return Positioned(
      bottom: 8,
      right: 8,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Publish state
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              participant.publishState == StageParticipantPublishState.published
                  ? Icons.upload
                  : Icons.upload_outlined,
              size: 12,
              color:
                  participant.publishState ==
                      StageParticipantPublishState.published
                  ? Colors.green
                  : Colors.grey,
            ),
          ),

          // Subscribe state (for remote participants)
          if (!participant.isLocal)
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                participant.subscribeState ==
                        StageParticipantSubscribeState.subscribed
                    ? Icons.download
                    : Icons.download_outlined,
                size: 12,
                color:
                    participant.subscribeState ==
                        StageParticipantSubscribeState.subscribed
                    ? Colors.green
                    : Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioOnlyToggle(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: () {
          if (participant.participantId != null) {
            FlutterIvsStage.toggleAudioOnlySubscribe(
              participant.participantId!,
            );
            HapticFeedback.lightImpact();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: participant.isAudioOnly ? Colors.orange : Colors.blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Audio Only:\n${participant.isAudioOnly ? 'YES' : 'NO'}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactOverlay() {
    return Positioned(
      bottom: 4,
      left: 4,
      right: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          participant.isLocal ? 'You' : participant.participantId ?? 'Unknown',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Color _getBorderColor() {
    final audioStream = participant.audioStream;
    final isAudioMuted = audioStream?.isMuted ?? true;

    if (isAudioMuted) {
      return Colors.red;
    }

    // In a real implementation, you would get volume level from the stream
    // For now, we'll use a static color
    return Colors.green;
  }

  double _getBorderWidth() {
    final audioStream = participant.audioStream;
    final isAudioMuted = audioStream?.isMuted ?? true;

    if (isAudioMuted) {
      return 2.0;
    }

    // In a real implementation, volume level would determine border width
    return 3.0;
  }
}
