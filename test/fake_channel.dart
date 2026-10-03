import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class FakeChannel implements WebSocketChannel {
  final incoming = StreamController<dynamic>();
  final List<Map<String, dynamic>> sent = [];
  final Completer<void> readiness = Completer<void>();
  late final WebSocketSink _sink = FakeSink(this);

  FakeChannel({bool ready = true}) {
    if (ready) readiness.complete();
  }
  void receive(Map<String, dynamic> message) =>
      incoming.add(jsonEncode(message));
  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  WebSocketSink get sink => _sink;
  @override
  Future<void> get ready => readiness.future;
  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSink implements WebSocketSink {
  final FakeChannel channel;
  bool closed = false;
  FakeSink(this.channel);
  @override
  void add(dynamic data) {
    if (closed) throw StateError('Socket closed');
    channel.sent.add(jsonDecode(data as String) as Map<String, dynamic>);
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
    unawaited(channel.incoming.close());
  }

  @override
  Future<void> get done => Future.value();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> ioEvent(
  String method,
  int sequence, {
  String session = 'io-session',
  bool removed = false,
}) => {
  'jsonrpc': '2.0',
  'method': method,
  'params': {
    'interface': 'aimeio',
    'unit_no': 0,
    'session_id': session,
    'sequence': sequence,
    'timestamp_ms': 1790985600000 + sequence,
    if (method == 'event.ledSet') ...{
      'api': 'aime_io_led_set_color',
      'r': 255,
      'g': 34,
      'b': 51,
    } else ...{
      'api': 'aime_io_nfc_get_aime_id',
      'backend': removed ? null : 'Remote',
      'previous_backend': null,
      'previous_card': null,
      'card': removed
          ? null
          : {
              'source': 'demo',
              'card': {
                'type': 'aime',
                'id': '',
                'sak': 8,
                'atqa': 1024,
                'accessCode': '01234567890123456789',
              },
              'duration': null,
              'disposable': null,
            },
    },
  },
};

Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) throw StateError('Timed out');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
