import 'package:flutter_test/flutter_test.dart';
import 'package:aimeio_remote_frontend/remote_crypto.dart';
import 'package:aimeio_remote_frontend/remote_sender.dart';

import 'fake_channel.dart';

void main() {
  final salt = List<int>.filled(16, 0x11);
  final url = Uri.parse('https://example.test/instance');
  const password = 'test-remote-password';
  late FakeChannel channel;
  late RemoteSender sender;

  setUp(() {
    channel = FakeChannel();
    sender = RemoteSender(salt: salt, connector: (_) => channel);
  });
  tearDown(() => sender.dispose());

  test('normalizes HTTP/WS URLs and overrides agent role', () {
    expect(
      RemoteSender.controllerUrl(
        Uri.parse(
          'https://example.test/room/?role=agent&token=keep&role=agent',
        ),
      ).toString(),
      'wss://example.test/room?role=controller&token=keep&card_protocol=2',
    );
    expect(
      RemoteSender.controllerUrl(
        Uri.parse('http://localhost:8787/room'),
      ).scheme,
      'ws',
    );
    expect(
      RemoteSender.controllerUrl(Uri.parse('ws://localhost/room')).scheme,
      'ws',
    );
    for (final invalid in [
      'file:///room',
      'https://example.test',
      'https://user@example.test/room',
    ]) {
      expect(
        () => RemoteSender.controllerUrl(Uri.parse(invalid)),
        throwsFormatException,
      );
    }
  });

  test('sends wrapped card and clear on the same persistent socket', () async {
    await sender.connect(url: url);
    await sender.sendCard(value: '0102030405060708090a', once: true);
    await sender.clearCard();
    expect(channel.sent, [
      {
        'action': 'SET_CARD',
        'body': {
          'type': 'aime',
          'value': '0102030405060708090a',
          'disposable': true,
        },
      },
      {'action': 'CLEAR_CARD'},
    ]);
    expect(
      () => sender.sendCard(value: '0123456789012345678x', once: true),
      throwsFormatException,
    );
  });

  test('encrypts card, clear, and expiring key commands', () async {
    await sender.connect(url: url, password: password);
    await sender.sendCard(value: '01234567890123456789', once: false);
    await sender.clearCard();
    await sender.sendKeyPress(key: 32, count: 2);
    final messages = await Future.wait(
      channel.sent.map(
        (envelope) =>
            RemoteCrypto.decryptMessage(password: password, envelope: envelope),
      ),
    );
    expect(messages[0]['action'], 'SET_CARD');
    expect(messages[1], {'action': 'CLEAR_CARD'});
    expect(messages[2], {
      'action': 'KEY_PRESS',
      'body': {'key': 32, 'count': 2},
    });
    expect(channel.sent[0]['body']['expires_at'], isNull);
    expect(
      channel.sent[2]['body']['expires_at'],
      greaterThan(DateTime.now().millisecondsSinceEpoch),
    );
  });

  test(
    'requires connection and validates key permissions and bounds',
    () async {
      await expectLater(sender.clearCard(), throwsStateError);
      await sender.connect(url: url);
      expect(
        () => sender.sendKeyPress(key: 32, count: 1),
        throwsFormatException,
      );
      channel = FakeChannel();
      await sender.connect(url: url, password: password);
      expect(
        () => sender.sendKeyPress(key: 32, count: 21),
        throwsFormatException,
      );
      expect(
        () => sender.sendKeyPress(key: -1, count: 1),
        throwsFormatException,
      );
    },
  );

  test('receives state, consumed, LED, and removal separately', () async {
    await sender.connect(url: url);
    channel.receive(ioEvent('event.cardStateChanged', 1));
    channel.receive(ioEvent('event.cardConsumed', 2));
    channel.receive(ioEvent('event.ledSet', 3));
    channel.receive(ioEvent('event.cardStateChanged', 4, removed: true));
    await waitFor(() => sender.events.length == 4);
    expect(sender.cardStates.values.single.card, isNull);
    expect(
      sender.consumedCards.values.single.card!['card']['accessCode'],
      '01234567890123456789',
    );
    expect(sender.leds.values.single.params['r'], 255);
    expect(sender.events.map((event) => event.sequence), [4, 3, 2, 1]);
  });

  test(
    'deduplicates per session, reports sequence gaps, bounds history',
    () async {
      await sender.connect(url: url);
      channel.receive(ioEvent('event.ledSet', 1));
      channel.receive(ioEvent('event.ledSet', 1));
      channel.receive(ioEvent('event.ledSet', 4));
      channel.receive(ioEvent('event.ledSet', 1, session: 'another-agent'));
      await waitFor(() => sender.events.length == 3);
      expect(sender.missedEvents, 2);
      expect(sender.leds.length, 2);
      for (var sequence = 5; sequence <= 120; sequence++) {
        channel.receive(ioEvent('event.ledSet', sequence));
      }
      await waitFor(() => sender.events.first.sequence == 120);
      expect(sender.events.length, 100);
      sender.clearEvents();
      channel.receive(ioEvent('event.ledSet', 120));
      channel.receive(ioEvent('event.ledSet', 121));
      await waitFor(() => sender.events.isNotEmpty);
      expect(sender.events.single.sequence, 121);
    },
  );

  test(
    'decrypts IO notifications, accepts hello, rejects downgrade and wrong password',
    () async {
      await sender.connect(url: url, password: password);
      channel.receive({
        'action': 'CLIENT_HELLO',
        'body': {'version': 2, 'event_protocol': 1},
      });
      final envelope = await RemoteCrypto.encryptMessage(
        password: password,
        message: ioEvent('event.cardConsumed', 1),
        salt: salt,
        messageId: 'encrypted-event',
      );
      channel.receive(envelope);
      channel.receive(envelope);
      await waitFor(() => sender.events.isNotEmpty);
      expect(sender.hello, contains('Events 1'));
      channel.receive(ioEvent('event.ledSet', 2));
      await waitFor(() => sender.lastError != null);
      expect(sender.lastError, contains('Plaintext event rejected'));
      channel.receive(
        await RemoteCrypto.encryptMessage(
          password: 'wrong-password',
          message: ioEvent('event.ledSet', 3),
          salt: salt,
          messageId: 'wrong-password',
        ),
      );
      await waitFor(() => sender.lastError!.contains('authentication failed'));
      expect(sender.events.length, 1);
      // A bad message must not stop processing later valid notifications.
      channel.receive(
        await RemoteCrypto.encryptMessage(
          password: password,
          message: ioEvent('event.ledSet', 2),
          salt: salt,
          messageId: 'recovery',
        ),
      );
      await waitFor(() => sender.events.length == 2);
      expect(sender.lastError, isNull);
    },
  );

  test('ignores expired encrypted notifications', () async {
    await sender.connect(url: url, password: password);
    channel.receive(
      await RemoteCrypto.encryptMessage(
        password: password,
        message: ioEvent('event.ledSet', 1),
        salt: salt,
        messageId: 'expired',
        expiresAt: 1,
      ),
    );
    channel.receive(
      await RemoteCrypto.encryptMessage(
        password: password,
        message: ioEvent('event.ledSet', 2),
        salt: salt,
        messageId: 'fresh',
      ),
    );
    await waitFor(() => sender.events.isNotEmpty);
    expect(sender.events.single.sequence, 2);
  });

  test('rejects invalid events without breaking the receive stream', () async {
    await sender.connect(url: url);
    final invalid = ioEvent('event.ledSet', 1);
    invalid['params']['r'] = 256;
    channel.receive(invalid);
    await waitFor(() => sender.lastError != null);
    expect(sender.events, isEmpty);
    channel.receive(ioEvent('event.ledSet', 2));
    await waitFor(() => sender.events.isNotEmpty);
  });

  test(
    'reconnects without replaying commands and stops on disconnect',
    () async {
      final channels = <FakeChannel>[];
      sender.dispose();
      sender = RemoteSender(
        salt: salt,
        reconnectDelay: const Duration(milliseconds: 5),
        connector: (_) {
          final channel = FakeChannel();
          channels.add(channel);
          return channel;
        },
      );
      await sender.connect(url: url);
      await sender.sendCard(value: '01234567890123456789', once: true);
      await channels.first.incoming.close();
      await waitFor(() => channels.length == 2 && sender.connected);
      expect(channels.last.sent, isEmpty);
      sender.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(channels.length, 2);
      expect(sender.active, isFalse);
    },
  );

  test('does not send an encrypted command after settings change', () async {
    await sender.connect(url: url, password: 'uncached-password');
    final sending = sender.sendKeyPress(key: 32, count: 1);
    sender.disconnect();
    await expectLater(sending, throwsStateError);
    expect(channel.sent, isEmpty);
  });

  test('disconnect invalidates a pending connection attempt', () async {
    final pending = FakeChannel(ready: false);
    sender.dispose();
    sender = RemoteSender(salt: salt, connector: (_) => pending);
    final opening = sender.connect(url: url);
    sender.disconnect();
    pending.readiness.complete();
    await opening;
    expect(sender.state, RemoteConnectionState.disconnected);
  });
}
