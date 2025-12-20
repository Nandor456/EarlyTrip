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
    // If we're reconnecting (e.g. after logout/login), fully dispose the old
    // connection first. socket_io_client can otherwise reuse a cached manager.
    if (_socket != null) {
      disconnect();
    }

    final redactedToken = accessToken.isEmpty
        ? '<empty>'
        : '${accessToken.substring(0, accessToken.length >= 8 ? 6 : 1)}…${accessToken.substring(accessToken.length >= 8 ? accessToken.length - 2 : accessToken.length - 1)}';
    debugPrint(
      'Socket.IO connecting to $serverUrl$path (token: $redactedToken)',
    );

    _socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'path': path,
      'extraHeaders': {'authorization': 'Bearer $accessToken'},
      'autoConnect': true,
      'reconnection': true,
      // Critical: do not reuse a cached Manager between logins.
      'forceNew': true,
    });

    _socket!.on("connect", (_) {
      debugPrint("✅ Connected to Socket.IO server");
    });

    _socket!.on("disconnect", (_) {
      debugPrint("❌ Disconnected from Socket.IO server");
    });

    _socket!.on("connect_error", (err) {
      debugPrint("❌ Socket.IO connect_error: $err");
    });

    _socket!.on("error", (err) {
      debugPrint("❌ Socket.IO error: $err");
    });

    _socket!.on("reconnect_attempt", (attempt) {
      debugPrint("↻ Socket.IO reconnect_attempt: $attempt");
    });

    _socket!.on("reconnect_error", (err) {
      debugPrint("❌ Socket.IO reconnect_error: $err");
    });

    _socket!.on("reconnect_failed", (_) {
      debugPrint("❌ Socket.IO reconnect_failed");
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
