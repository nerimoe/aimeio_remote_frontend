import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'remote_crypto.dart';
import 'remote_events.dart';

typedef RemoteConnector = WebSocketChannel Function(Uri url);

enum RemoteConnectionState { disconnected, connecting, connected, reconnecting }

/// One persistent Controller connection. Commands are never queued or replayed.
class RemoteSender extends ChangeNotifier {
  static const _uuid = Uuid();
  final List<int> _salt;
  final RemoteConnector _connector;
  final Duration reconnectDelay;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  Uri? _url;
  String _password = '';
  int _generation = 0;
  bool _disposed = false;
  bool _desired = false;
  int _retryCount = 0;
  final _lastSequences = <String, int>{};
  final _seenEnvelopes = <String>{};

  RemoteConnectionState state = RemoteConnectionState.disconnected;
  String? lastError;
  String? hello;
  int missedEvents = 0;
  final List<RemoteIoEvent> events = [];
  final Map<String, RemoteIoEvent> cardStates = {};
  final Map<String, RemoteIoEvent> consumedCards = {};
  final Map<String, RemoteIoEvent> leds = {};

  RemoteSender({
    required List<int> salt,
    RemoteConnector? connector,
    this.reconnectDelay = const Duration(seconds: 2),
  }) : _salt = List.unmodifiable(salt),
       _connector = connector ?? WebSocketChannel.connect {
    RemoteCrypto.encodeSalt(_salt);
  }

  bool get connected => state == RemoteConnectionState.connected;
  bool get active => _desired;

  static Uri controllerUrl(Uri url) {
    if (!{'http', 'https', 'ws', 'wss'}.contains(url.scheme) ||
        url.host.isEmpty ||
        url.path.replaceAll('/', '').isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasFragment) {
      throw const FormatException(
        'Enter a Relay instance HTTP(S) or WS(S) URL',
      );
    }
    return url.replace(
      scheme: switch (url.scheme) {
        'http' => 'ws',
        'https' => 'wss',
        _ => url.scheme,
      },
      path: url.path.replaceFirst(RegExp(r'/+$'), ''),
      queryParameters: {
        ...url.queryParameters,
        'role': 'controller',
        'card_protocol': '2',
      },
    );
  }

  Future<void> connect({required Uri url, String password = ''}) async {
    final normalized = controllerUrl(url);
    disconnect();
    clearEvents();
    _url = normalized;
    _password = password;
    _desired = true;
    _retryCount = 0;
    await _open(_generation);
  }

  Future<void> _open(int generation) async {
    if (!_current(generation)) return;
    state = _retryCount == 0
        ? RemoteConnectionState.connecting
        : RemoteConnectionState.reconnecting;
    lastError = null;
    _notify();
    WebSocketChannel? channel;
    try {
      channel = _connector(_url!);
      _channel = channel;
      // asyncMap serializes decryption so notifications keep wire order.
      _subscription = channel.stream
          .asyncMap((raw) async {
            try {
              await _receive(raw, generation);
            } catch (error) {
              if (_current(generation)) {
                lastError = 'Incoming message: $error';
                _notify();
              }
            }
          })
          .listen(
            (_) {},
            onError: (Object error) {
              _lost(generation, channel!, error.toString());
            },
            onDone: () {
              _lost(generation, channel!, 'Relay connection closed');
            },
          );
      await channel.ready.timeout(const Duration(seconds: 10));
      if (!_current(generation) || _channel != channel) return;
      state = RemoteConnectionState.connected;
      _retryCount = 0;
      _notify();
    } catch (error) {
      if (channel != null) {
        _lost(generation, channel, 'Connection failed: $error');
      } else if (_current(generation)) {
        _scheduleRetry(generation, 'Connection failed: $error');
      }
    }
  }

  void _lost(int generation, WebSocketChannel channel, String error) {
    if (!_current(generation) || _channel != channel) return;
    _channel = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(channel.sink.close());
    _scheduleRetry(generation, error);
  }

  void _scheduleRetry(int generation, String error) {
    if (!_current(generation) || _retry != null) return;
    state = RemoteConnectionState.reconnecting;
    hello = null;
    lastError = error;
    _retryCount++;
    final multiplier = 1 << (_retryCount - 1).clamp(0, 4);
    _retry = Timer(reconnectDelay * multiplier, () {
      _retry = null;
      unawaited(_open(generation));
    });
    _notify();
  }

  bool _current(int generation) =>
      !_disposed && _desired && generation == _generation;

  void disconnect() {
    _desired = false;
    _generation++;
    _retry?.cancel();
    _retry = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_channel?.sink.close());
    _channel = null;
    state = RemoteConnectionState.disconnected;
    hello = null;
    lastError = null;
    _notify();
  }

  Future<void> sendCard({required String value, required bool once}) {
    if (!RegExp(r'^[0-9a-fA-F]{20}$').hasMatch(value)) {
      throw const FormatException(
        'Access Code must contain 20 hexadecimal characters',
      );
    }
    return _send({
      'action': 'SET_CARD',
      'body': {'type': 'aime', 'value': value, 'disposable': once},
    });
  }

  Future<void> clearCard() => _send({'action': 'CLEAR_CARD'});

  Future<void> sendKeyPress({required int key, required int count}) {
    if (_password.isEmpty) {
      throw const FormatException(
        'A password is required for remote key press',
      );
    }
    if (key < 0 || key > 0xffffffff || count < 1 || count > 20) {
      throw const FormatException('Invalid key code or press count (1–20)');
    }
    return _send(
      {
        'action': 'KEY_PRESS',
        'body': {'key': key, 'count': count},
      },
      expiresAt: DateTime.now()
          .add(const Duration(seconds: 30))
          .millisecondsSinceEpoch,
    );
  }

  Future<void> _send(Map<String, dynamic> message, {int? expiresAt}) async {
    final channel = _channel;
    final generation = _generation;
    if (!connected || channel == null) {
      throw StateError('Connect to Relay first');
    }
    final payload = _password.isEmpty
        ? message
        : await RemoteCrypto.encryptMessage(
            password: _password,
            message: message,
            salt: _salt,
            messageId: _uuid.v4(),
            expiresAt: expiresAt,
          );
    if (!_current(generation) || !connected || _channel != channel) {
      throw StateError('Connection changed; command was not sent');
    }
    channel.sink.add(jsonEncode(payload));
  }

  Future<void> _receive(dynamic raw, int generation) async {
    if (!_current(generation)) return;
    if (raw is! String) throw const FormatException('Expected a text message');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Expected a JSON object');
    var message = Map<String, dynamic>.from(decoded);
    // IO advertises capabilities in plaintext even when a password is set.
    if (message['action'] == 'CLIENT_HELLO') {
      final body = message['body'];
      if (body is! Map) throw const FormatException('Invalid CLIENT_HELLO');
      hello =
          'IO protocol ${body['version']} · Events ${body['event_protocol'] ?? 'unsupported'}';
      _notify();
      return;
    }
    String? envelopeId;
    if (message['action'] == 'E2EE_V1') {
      message = await RemoteCrypto.decryptMessage(
        password: _password,
        envelope: message,
      );
      if (!_current(generation)) return;
      final body = Map<String, dynamic>.from(decoded['body'] as Map);
      final expires = body['expires_at'] as int?;
      if (expires != null && expires <= DateTime.now().millisecondsSinceEpoch) {
        return;
      }
      envelopeId = body['message_id'] as String;
      if (_seenEnvelopes.contains(envelopeId)) return;
    } else if (_password.isNotEmpty) {
      throw const FormatException(
        'Plaintext event rejected: password is configured',
      );
    }
    final event = RemoteIoEvent.parse(message);
    if (event == null) return;
    final previous = _lastSequences[event.sessionId];
    if (previous != null && event.sequence <= previous) return;
    if (previous != null && event.sequence > previous + 1) {
      missedEvents += event.sequence - previous - 1;
    }
    _lastSequences[event.sessionId] = event.sequence;
    if (_lastSequences.length > 64) {
      _lastSequences.remove(_lastSequences.keys.first);
    }
    if (envelopeId != null) {
      _seenEnvelopes.add(envelopeId);
      if (_seenEnvelopes.length > 256) {
        _seenEnvelopes.remove(_seenEnvelopes.first);
      }
    }
    final target = switch (event.method) {
      'event.cardStateChanged' => cardStates,
      'event.cardConsumed' => consumedCards,
      _ => leds,
    };
    target[event.readerKey] = event;
    if (target.length > 64) target.remove(target.keys.first);
    events.insert(0, event);
    if (events.length > 100) events.removeLast();
    lastError = null;
    _notify();
  }

  void clearEvents() {
    events.clear();
    cardStates.clear();
    consumedCards.clear();
    leds.clear();
    // Keep sequence/envelope tracking when merely clearing the display.
    missedEvents = 0;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    super.dispose();
  }
}
