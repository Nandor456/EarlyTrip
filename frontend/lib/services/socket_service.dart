import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  IO.Socket? _socket;

  SocketService._internal();

  bool get isInitialized => _socket != null;

  IO.Socket get socket {
    final s = _socket;
    if (s == null) {
      throw StateError('Socket is not initialized. Call connect() first.');
    }
    return s;
  }

  void connect(String serverUrl, String accessToken, {String path = "/ws"}) {
    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket']) // use WebSocket only
          .setPath(path) // match server path, e.g. "/ws"
          .setExtraHeaders({
            'authorization': 'Bearer $accessToken',
          }) // Send as header
          .enableAutoConnect()
          .build(),
    );

    _socket!.on("connect", (_) {
      debugPrint("✅ Connected to Socket.IO server");
    });

    _socket!.on("disconnect", (_) {
      debugPrint("❌ Disconnected from Socket.IO server");
    });
  }

  void joinGroup(String groupId) {
    socket.emit("join_group", groupId);
  }

  void sendMessage(String groupId, Map<String, dynamic> message) {
    socket.emit("send_message", {"groupId": groupId, "message": message});
  }

  void onNewMessage(Function(dynamic) callback) {
    socket.on("new_message", callback);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
