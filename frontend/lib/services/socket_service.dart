import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  late IO.Socket socket;

  SocketService._internal();

  void connect(String serverUrl, {String path = "/ws"}) {
    socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket']) // use WebSocket only
          .setPath(path) // match server path, e.g. "/ws"
          .enableAutoConnect()
          .build(),
    );

    socket.on("connect", (_) {
      print("✅ Connected to Socket.IO server");
    });

    socket.on("disconnect", (_) {
      print("❌ Disconnected from Socket.IO server");
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
    socket.disconnect();
  }
}
