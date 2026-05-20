// lib/services/ws_client.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../models/events.dart';
import 'ws_connector_io.dart' if (dart.library.html) 'ws_connector_web.dart';

typedef EventHandler = void Function(EventBase evt);
typedef StateHandler = void Function(String state);

class WsClient {
  WsClient(this.endpoint, {this.onEvent, this.onState});

  static const Duration _reconnectDelay = Duration(seconds: 3);

  final String endpoint;
  final EventHandler? onEvent;
  final StateHandler? onState;

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _retry;
  bool _disposed = false;

  Future<void> connect() async {
    if (_disposed) return;
    onState?.call('connecting');
    try {
      final ch = platformConnectWs(Uri.parse(endpoint));
      _ch = ch;
      _sub = ch.stream.listen(
        _onMessage,
        onDone: () {
          onState?.call('disconnected');
          _scheduleReconnect();
        },
        onError: (e, st) {
          debugPrint('[WS] onError $e');
          onState?.call('error');
          _scheduleReconnect();
        },
      );
      // 실제 핸드셰이크 완료까지 대기
      await ch.ready;
      if (_disposed) return;
      onState?.call('connected');
    } catch (e) {
      debugPrint('[WS] connect error: $e');
      onState?.call('error');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final text = (data is List<int>) ? utf8.decode(data) : data.toString();
      final obj = json.decode(text);

      if (obj is Map<String, dynamic>) {
        onEvent?.call(EventBase.fromJson(obj));
      } else if (obj is List) {
        for (final it in obj) {
          if (it is Map<String, dynamic>) {
            onEvent?.call(EventBase.fromJson(it));
          }
        }
      } else {
        onEvent?.call(UnknownEvent({'raw': obj}));
      }
    } catch (e, st) {
      debugPrint('[WS][onMessage][ERROR] $e\n$st');
    }
  }

  void sendJson(Map<String, dynamic> data) => sendString(jsonEncode(data));

  void sendString(String s) {
    try {
      _ch?.sink.add(s);
    } catch (e) {
      debugPrint('[WS] send error: $e');
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _retry?.cancel();
    onState?.call('reconnecting');
    _retry = Timer(_reconnectDelay, () => unawaited(connect()));
  }

  Future<void> dispose() async {
    _disposed = true;
    _retry?.cancel();
    try {
      await _sub?.cancel();
    } catch (_) {}
    try {
      await _ch?.sink.close(ws_status.normalClosure);
    } catch (_) {}
  }
}
