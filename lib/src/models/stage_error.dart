/// Represents an error that occurred in the stage
class StageError {
  final String title;
  final String message;
  final int? code;
  final String? source;

  const StageError({
    required this.title,
    required this.message,
    this.code,
    this.source,
  });

  factory StageError.fromMap(Map<String, dynamic> map) {
    return StageError(
      title: map['title'] ?? 'Unknown Error',
      message: map['message'] ?? 'An unknown error occurred',
      code: map['code'],
      source: map['source'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'code': code,
      'source': source,
    };
  }

  @override
  String toString() {
    return 'StageError(title: $title, message: $message, code: $code, source: $source)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StageError &&
        other.title == title &&
        other.message == message &&
        other.code == code &&
        other.source == source;
  }

  @override
  int get hashCode {
    return title.hashCode ^ message.hashCode ^ code.hashCode ^ source.hashCode;
  }
}
