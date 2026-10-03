import 'package:flutter/material.dart';

/// JSON-RPC notifications from IO event_protocol 1.
class RemoteIoEvent {
  static const methods = {
    'event.cardStateChanged',
    'event.cardConsumed',
    'event.ledSet',
  };

  final String method;
  final Map<String, dynamic> params;

  RemoteIoEvent._(this.method, this.params);

  static RemoteIoEvent? parse(Map<String, dynamic> message) {
    if (message['jsonrpc'] != '2.0' ||
        message.containsKey('id') ||
        !methods.contains(message['method'])) {
      return null;
    }
    final value = message['params'];
    if (value is! Map) throw const FormatException('Invalid IO event params');
    final params = Map<String, dynamic>.from(value);
    if (params['session_id'] is! String ||
        (params['session_id'] as String).isEmpty ||
        params['sequence'] is! int ||
        (params['sequence'] as int) < 1 ||
        params['timestamp_ms'] is! int ||
        !{'aimeio', 'tal'}.contains(params['interface']) ||
        params['unit_no'] is! int ||
        (params['unit_no'] as int) < 0) {
      throw const FormatException('Invalid IO event metadata');
    }
    final method = message['method'] as String;
    if (method == 'event.ledSet') {
      for (final component in ['r', 'g', 'b']) {
        final channel = params[component];
        if (channel is! int || channel < 0 || channel > 255) {
          throw const FormatException('Invalid IO LED color');
        }
      }
    } else {
      final card = params['card'];
      if (!params.containsKey('card') ||
          (card != null && (card is! Map || card['card'] is! Map)) ||
          (method == 'event.cardConsumed' && card == null)) {
        throw const FormatException('Invalid IO card snapshot');
      }
    }
    return RemoteIoEvent._(method, Map.unmodifiable(params));
  }

  String get sessionId => params['session_id'] as String;
  int get sequence => params['sequence'] as int;
  DateTime get timestamp =>
      DateTime.fromMillisecondsSinceEpoch(params['timestamp_ms'] as int);
  String get reader => '${params['interface']} / ${params['unit_no']}';
  String get readerKey => '$sessionId/$reader';
  Map<String, dynamic>? get card => params['card'] == null
      ? null
      : Map<String, dynamic>.from(params['card'] as Map);
  Color get color => Color.fromARGB(
    255,
    params['r'] as int,
    params['g'] as int,
    params['b'] as int,
  );

  String get title => switch (method) {
    'event.cardStateChanged' => card == null ? 'Card removed' : 'Card detected',
    'event.cardConsumed' => 'Card delivered to game',
    _ => 'Game LED command',
  };

  String get details {
    if (method == 'event.ledSet') {
      return '$reader · RGB ${params['r']}, ${params['g']}, ${params['b']}';
    }
    final snapshot = card;
    final identity = snapshot == null ? 'No card' : describeCard(snapshot);
    final origin = method == 'event.cardConsumed'
        ? params['api']
        : params['backend'];
    return '$reader · $identity${origin == null ? '' : ' · $origin'}';
  }

  static String describeCard(Map<String, dynamic> snapshot) {
    final card = Map<String, dynamic>.from(snapshot['card'] as Map);
    final identity = card['accessCode'] ?? card['cardNumber'] ?? card['id'];
    return '${card['type']} ${identity ?? ''}'.trim();
  }
}
