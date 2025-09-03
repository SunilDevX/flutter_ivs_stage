/// Stage connection states
enum StageConnectionState {
  disconnected,
  connecting,
  connected;

  static StageConnectionState fromString(String? value) {
    switch (value) {
      case 'disconnected':
        return StageConnectionState.disconnected;
      case 'connecting':
        return StageConnectionState.connecting;
      case 'connected':
        return StageConnectionState.connected;
      default:
        return StageConnectionState.disconnected;
    }
  }
}
