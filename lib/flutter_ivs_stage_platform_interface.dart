import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_ivs_stage_method_channel.dart';
import 'src/models/models.dart';

abstract class FlutterIvsStagePlatform extends PlatformInterface {
  /// Constructs a FlutterIvsStagePlatform.
  FlutterIvsStagePlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterIvsStagePlatform _instance = MethodChannelFlutterIvsStage();

  /// The default instance of [FlutterIvsStagePlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterIvsStage].
  static FlutterIvsStagePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterIvsStagePlatform] when
  /// they register themselves.
  static set instance(FlutterIvsStagePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> joinStage(String token) {
    throw UnimplementedError('joinStage() has not been implemented.');
  }

  Future<void> leaveStage() {
    throw UnimplementedError('leaveStage() has not been implemented.');
  }

  Future<void> toggleLocalAudioMute() {
    throw UnimplementedError('toggleLocalAudioMute() has not been implemented.');
  }

  Future<void> toggleLocalVideoMute() {
    throw UnimplementedError('toggleLocalVideoMute() has not been implemented.');
  }

  Future<void> toggleAudioOnlySubscribe(String participantId) {
    throw UnimplementedError('toggleAudioOnlySubscribe() has not been implemented.');
  }

  Future<bool> setBroadcastAuth(String endpoint, String streamKey) {
    throw UnimplementedError('setBroadcastAuth() has not been implemented.');
  }

  Future<void> toggleBroadcasting() {
    throw UnimplementedError('toggleBroadcasting() has not been implemented.');
  }

  Future<bool> requestPermissions() {
    throw UnimplementedError('requestPermissions() has not been implemented.');
  }

  Future<bool> checkPermissions() {
    throw UnimplementedError('checkPermissions() has not been implemented.');
  }

  Stream<List<StageParticipant>> get participantsStream {
    throw UnimplementedError('participantsStream has not been implemented.');
  }

  Stream<StageConnectionState> get connectionStateStream {
    throw UnimplementedError('connectionStateStream has not been implemented.');
  }

  Stream<bool> get localAudioMutedStream {
    throw UnimplementedError('localAudioMutedStream has not been implemented.');
  }

  Stream<bool> get localVideoMutedStream {
    throw UnimplementedError('localVideoMutedStream has not been implemented.');
  }

  Stream<bool> get broadcastingStream {
    throw UnimplementedError('broadcastingStream has not been implemented.');
  }

  Stream<StageError> get errorStream {
    throw UnimplementedError('errorStream has not been implemented.');
  }

  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }
}
