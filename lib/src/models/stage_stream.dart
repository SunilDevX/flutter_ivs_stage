/// Represents a media stream in a stage
class StageStream {
  final String deviceId;
  final StageStreamType type;
  final bool isMuted;
  final Map<String, dynamic>? metadata;

  const StageStream({
    required this.deviceId,
    required this.type,
    this.isMuted = false,
    this.metadata,
  });

  factory StageStream.fromMap(Map<String, dynamic> map) {
    return StageStream(
      deviceId: map['deviceId'] ?? '',
      type: StageStreamType.fromString(map['type']),
      isMuted: map['isMuted'] ?? false,
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'type': type.name,
      'isMuted': isMuted,
      'metadata': metadata,
    };
  }

  StageStream copyWith({
    String? deviceId,
    StageStreamType? type,
    bool? isMuted,
    Map<String, dynamic>? metadata,
  }) {
    return StageStream(
      deviceId: deviceId ?? this.deviceId,
      type: type ?? this.type,
      isMuted: isMuted ?? this.isMuted,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'StageStream(deviceId: $deviceId, type: $type, isMuted: $isMuted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StageStream &&
        other.deviceId == deviceId &&
        other.type == type &&
        other.isMuted == isMuted;
  }

  @override
  int get hashCode {
    return deviceId.hashCode ^ type.hashCode ^ isMuted.hashCode;
  }
}

/// Types of stage streams
enum StageStreamType {
  audio,
  video;

  static StageStreamType fromString(String? value) {
    switch (value) {
      case 'audio':
        return StageStreamType.audio;
      case 'video':
        return StageStreamType.video;
      default:
        return StageStreamType.video;
    }
  }
}
