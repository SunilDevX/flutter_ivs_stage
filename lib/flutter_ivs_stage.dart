import 'dart:async';

import 'flutter_ivs_stage_platform_interface.dart';
import 'src/models/models.dart';

export 'src/models/models.dart';
export 'src/widgets/widgets.dart';

class FlutterIvsStage {
  static FlutterIvsStagePlatform get _platform =>
      FlutterIvsStagePlatform.instance;

  /// Get the SDK version
  static Future<String?> getPlatformVersion() {
    return _platform.getPlatformVersion();
  }

  /// Join a stage with the given token
  static Future<void> joinStage(String token) {
    return _platform.joinStage(token);
  }

  /// Leave the current stage
  static Future<void> leaveStage() {
    return _platform.leaveStage();
  }

  /// Toggle local audio mute
  static Future<void> toggleLocalAudioMute() {
    return _platform.toggleLocalAudioMute();
  }

  /// Toggle local video mute
  static Future<void> toggleLocalVideoMute() {
    return _platform.toggleLocalVideoMute();
  }

  /// Toggle audio-only subscription for a participant
  static Future<void> toggleAudioOnlySubscribe(String participantId) {
    return _platform.toggleAudioOnlySubscribe(participantId);
  }

  /// Set broadcast authentication
  static Future<bool> setBroadcastAuth(String endpoint, String streamKey) {
    return _platform.setBroadcastAuth(endpoint, streamKey);
  }

  /// Toggle broadcasting
  static Future<void> toggleBroadcasting() {
    return _platform.toggleBroadcasting();
  }

  /// Request camera and microphone permissions
  static Future<bool> requestPermissions() {
    return _platform.requestPermissions();
  }

  /// Check if permissions are granted
  static Future<bool> checkPermissions() {
    return _platform.checkPermissions();
  }

  /// Stream of participants data
  static Stream<List<StageParticipant>> get participantsStream {
    return _platform.participantsStream;
  }

  /// Stream of stage connection state
  static Stream<StageConnectionState> get connectionStateStream {
    return _platform.connectionStateStream;
  }

  /// Stream of local user audio mute state
  static Stream<bool> get localAudioMutedStream {
    return _platform.localAudioMutedStream;
  }

  /// Stream of local user video mute state
  static Stream<bool> get localVideoMutedStream {
    return _platform.localVideoMutedStream;
  }

  /// Stream of broadcasting state
  static Stream<bool> get broadcastingStream {
    return _platform.broadcastingStream;
  }

  /// Stream of error events
  static Stream<StageError> get errorStream {
    return _platform.errorStream;
  }

  /// Dispose resources
  static Future<void> dispose() {
    return _platform.dispose();
  }
}
