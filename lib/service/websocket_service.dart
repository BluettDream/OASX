import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef MessageListener = void Function(dynamic message);

class WebSocketManager extends GetxService {
  static WebSocketManager get instance => Get.find<WebSocketManager>();

  final Map<String, WebSocketClient> _clients = {};

  Future<WebSocketManager> init() async {
    return this;
  }

  Future<WebSocketClient> connect(
      {required String name,
      String? url,
      MessageListener? listener,
      bool force = false}) async {
    if (!force && _clients.containsKey(name)) {
      return _clients[name]!._addListener(listener);
    }
    if(force && _clients.containsKey(name)){
      close(name);
    }

    url ??= 'ws://${ApiClient().address}/ws/$name';
    final client = WebSocketClient(
      name: name,
      url: url,
    )._addListener(listener);
    _clients[name] = client;
    await client._connect();
    return client;
  }

  void send(String name, String message) {
    final client = _clients[name];
    if (client != null) {
      client.send(message);
    } else {
      printInfo(info: "WebSocket [$name] not connected");
    }
  }

  Future<void> close(String name,
      {int code = WebSocketStatus.normalClosure,
      String reason = "normal close",
      bool reconnect = false}) async {
    final client = _clients[name];
    if (client != null) {
      await client._close(code, reason, reconnect: reconnect);
      _clients.remove(name);
    }
  }

  Future<void> closeAll() async {
    for (final client in _clients.values) {
      await client._close(WebSocketStatus.normalClosure, "global close");
    }
    _clients.clear();
  }
}

enum WsStatus {
  connecting,
  connected,
  reconnecting,
  closed,
  error,
}

class WebSocketClient {
  final String name;
  final String url;

  WebSocketChannel? _channel;
  final List<MessageListener> _listeners = [];
  bool _shouldReconnect = true;
  int _reconnectCount = 0;
  static const int maxReconnect = 10;
  final status = WsStatus.connecting.obs;

  WebSocketClient({
    required this.name,
    required this.url,
  });

  void send(String data) {
    if (status.value == WsStatus.connected) {
      _channel?.sink.add(data);
    } else {
      printInfo(info: "[$name] cannot send, status=${status.value}");
    }
  }

  Future<void> _connect() async {
    try {
      status.value = WsStatus.connecting;
      var address = url;
      if (address.contains('http://')) {
        address = address.replaceAll('http://', '');
      }
      printInfo(info: "[$name] connecting to $address");
      _channel = WebSocketChannel.connect(Uri.parse(address));
      await _channel!.ready;

      status.value = WsStatus.connected;
      printInfo(info: "[$name] ws connected!");

      _channel!.stream.listen(
        (msg) {
          for (final listener in _listeners) {
            listener(msg);
          }
        },
        onDone: _reconnect,
        onError: (e) {
          printError(info: "[$name] WebSocket error: $e");
          status.value = WsStatus.error;
          _reconnect();
        },
      );
    } on SocketException {
      printError(info: "[$name] SocketException: $url");
      status.value = WsStatus.error;
      _reconnect();
    } on Exception catch (e) {
      printError(info: "[$name] WebSocket Exception: $e");
      status.value = WsStatus.error;
      _reconnect();
    }
  }

  WebSocketClient _addListener(MessageListener? listener) {
    if (listener != null && !_listeners.contains(listener)) {
      _listeners.add(listener);
      if (kDebugMode) {
        printInfo(info: "ws listener add success!");
      }
    }
    return this;
  }

  void _removeListener(MessageListener listener) {
    _listeners.remove(listener);
  }

  Future<void> _close(int code, String reason, {bool reconnect = false}) async {
    _shouldReconnect = reconnect;
    printInfo(info: "[$name] closing: $reason");
    await _channel?.sink.close(code, reason);
    status.value = WsStatus.closed;
    _listeners.clear();
  }

  void _reconnect() {
    if (!_shouldReconnect) {
      printInfo(info: "[$name] closed intentionally, no reconnect");
      status.value = WsStatus.closed;
      return;
    }
    _reconnectCount++;
    if (_reconnectCount > maxReconnect) {
      printInfo(info: "[$name] reconnect failed more than $maxReconnect times");
      status.value = WsStatus.error;
      return;
    }
    printInfo(info: "[$name] reconnecting... ($_reconnectCount)");
    status.value = WsStatus.reconnecting;
    Future.delayed(const Duration(seconds: 2), () => _connect());
  }
}
