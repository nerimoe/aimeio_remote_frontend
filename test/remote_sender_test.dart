import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:aimeio_remote_frontend/remote_crypto.dart';
import 'package:aimeio_remote_frontend/remote_sender.dart';
import 'package:http/http.dart' as http;

class RecordingClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('{}')),
      200,
      request: request,
    );
  }
}

void main() {
  final salt = List<int>.filled(16, 0x11);

  test('sends a legacy disposable card when password is empty', () async {
    final client = RecordingClient();
    final sender = RemoteSender(client: client, salt: salt);

    final response = await sender.sendCard(
      url: Uri.parse('https://example.test/instance'),
      value: '0102030405060708090a',
      once: true,
    );

    final request = client.requests.single as http.Request;
    expect(response.statusCode, 200);
    expect(request.url.toString(), 'https://example.test/instance');
    expect(jsonDecode(request.body), {
      'type': 'aime',
      'value': '0102030405060708090a',
      'disposable': true,
    });
  });

  test(
    'sends an encrypted SET_CARD message when password is configured',
    () async {
      final client = RecordingClient();
      final sender = RemoteSender(client: client, salt: salt);

      await sender.sendCard(
        url: Uri.parse('https://example.test/instance'),
        value: '0102030405060708090a',
        once: false,
        password: 'test-remote-password',
      );

      final request = client.requests.single as http.Request;
      final envelope = jsonDecode(request.body) as Map<String, dynamic>;
      final message = await RemoteCrypto.decryptMessage(
        password: 'test-remote-password',
        envelope: envelope,
      );

      expect(envelope['action'], 'E2EE_V1');
      expect(message, {
        'action': 'SET_CARD',
        'body': {
          'type': 'aime',
          'value': '0102030405060708090a',
          'disposable': false,
        },
      });
    },
  );

  test('sends an encrypted key event to the instance event endpoint', () async {
    final client = RecordingClient();
    final sender = RemoteSender(client: client, salt: salt);
    final before = DateTime.now().millisecondsSinceEpoch;

    await sender.sendKeyPress(
      url: Uri.parse('https://example.test/instance'),
      key: 32,
      count: 2,
      password: 'test-remote-password',
    );

    final request = client.requests.single as http.Request;
    final envelope = jsonDecode(request.body) as Map<String, dynamic>;
    final body = envelope['body'] as Map<String, dynamic>;
    final message = await RemoteCrypto.decryptMessage(
      password: 'test-remote-password',
      envelope: envelope,
    );
    final expiresAt = body['expires_at'] as int;

    expect(request.url.toString(), 'https://example.test/instance/event');
    expect(envelope['action'], 'E2EE_V1');
    expect(message, {
      'action': 'KEY_PRESS',
      'body': {'key': 32, 'count': 2},
    });
    expect(expiresAt, greaterThan(before));
    expect(expiresAt, lessThan(before + 60000));
  });

  test(
    'rejects key events without a password or with an invalid count',
    () async {
      final sender = RemoteSender(client: RecordingClient(), salt: salt);

      expect(
        () => sender.sendKeyPress(
          url: Uri.parse('https://example.test/instance'),
          key: 32,
          count: 1,
          password: '',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => sender.sendKeyPress(
          url: Uri.parse('https://example.test/instance'),
          key: 32,
          count: 21,
          password: 'test-remote-password',
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
