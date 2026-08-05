import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'remote_crypto.dart';

class RemoteSender {
  static const _keyPressExpiration = Duration(seconds: 30);
  static const _maxKeyPressCount = 20;
  static const _uuid = Uuid();

  final http.Client _client;
  final List<int> _salt;

  RemoteSender({http.Client? client, required List<int> salt})
    : _client = client ?? http.Client(),
      _salt = List<int>.unmodifiable(salt) {
    RemoteCrypto.encodeSalt(_salt);
  }

  Future<http.Response> sendCard({
    required Uri url,
    required String value,
    required bool once,
    String password = '',
  }) async {
    final card = {'type': 'aime', 'value': value, 'disposable': once};
    final payload = password.isEmpty
        ? card
        : await RemoteCrypto.encryptMessage(
            password: password,
            message: {'action': 'SET_CARD', 'body': card},
            salt: _salt,
            messageId: _uuid.v4(),
          );

    return _postJson(url, payload);
  }

  Future<http.Response> sendKeyPress({
    required Uri url,
    required int key,
    required int count,
    required String password,
  }) async {
    if (password.isEmpty) {
      throw const FormatException(
        'A password is required for remote key press',
      );
    }
    if (key < 0 || key > 0xffffffff) {
      throw const FormatException(
        'Key code must fit in an unsigned 32-bit integer',
      );
    }
    if (count < 1 || count > _maxKeyPressCount) {
      throw const FormatException('Key press count must be between 1 and 20');
    }

    final expiresAt = DateTime.now()
        .add(_keyPressExpiration)
        .millisecondsSinceEpoch;
    final payload = await RemoteCrypto.encryptMessage(
      password: password,
      message: {
        'action': 'KEY_PRESS',
        'body': {'key': key, 'count': count},
      },
      salt: _salt,
      messageId: _uuid.v4(),
      expiresAt: expiresAt,
    );

    return _postJson(_eventUrl(url), payload);
  }

  Future<http.Response> _postJson(Uri url, Map<String, dynamic> payload) {
    return _client.post(
      url,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
  }

  Uri _eventUrl(Uri url) {
    final path = url.path.replaceFirst(RegExp(r'/$'), '');
    return url.replace(path: '$path/event');
  }
}
