import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aimeio_remote_frontend/remote_crypto.dart';
import 'package:aimeio_remote_frontend/remote_sender.dart';

import 'fake_channel.dart';

void main() {
  final base = Platform.environment['RELAY_TEST_URL'];
  final ioRoot = Platform.environment['AIMEIO_ROOT'];
  final salt = List<int>.filled(16, 0x11);

  for (final password in ['', 'test-remote-password']) {
    final mode = password.isEmpty ? 'plaintext' : 'encrypted';
    test(
      'Controller <-> local Relay <-> Agent ($mode)',
      () async {
        final url = Uri.parse('$base-$mode');
        final sender = RemoteSender(salt: salt);
        final agent = await WebSocket.connect(
          url
              .replace(
                scheme: 'ws',
                queryParameters: {'role': 'agent', 'card_protocol': '2'},
              )
              .toString(),
        );
        addTearDown(() async {
          sender.dispose();
          await agent.close();
        });
        final commands = <Map<String, dynamic>>[];
        agent.listen((raw) {
          commands.add(jsonDecode(raw as String) as Map<String, dynamic>);
        });
        await sender.connect(url: url, password: password);
        expect(sender.connected, isTrue);
        await sender.sendCard(value: '01234567890123456789', once: false);
        await waitFor(() => commands.length == 1);
        Future<Map<String, dynamic>> unwrap(
          Map<String, dynamic> message,
        ) async => password.isEmpty
            ? message
            : RemoteCrypto.decryptMessage(
                password: password,
                envelope: message,
              );
        expect((await unwrap(commands.single))['action'], 'SET_CARD');
        agent.add(
          jsonEncode({
            'action': 'CLIENT_HELLO',
            'body': {'version': 2, 'event_protocol': 1},
          }),
        );
        var sequence = 0;
        for (final method in [
          'event.cardStateChanged',
          'event.cardConsumed',
          'event.ledSet',
        ]) {
          final event = ioEvent(method, ++sequence);
          agent.add(
            jsonEncode(
              password.isEmpty
                  ? event
                  : await RemoteCrypto.encryptMessage(
                      password: password,
                      message: event,
                      salt: salt,
                      messageId: '$mode-$sequence',
                    ),
            ),
          );
        }
        await waitFor(() => sender.events.length == 3);
        expect(sender.hello, contains('Events 1'));
        expect(
          sender.cardStates.values.single.card!['card']['accessCode'],
          '01234567890123456789',
        );
        expect(sender.consumedCards.length, 1);
        expect(sender.leds.values.single.params['r'], 255);
        if (password.isNotEmpty) {
          await sender.sendKeyPress(key: 32, count: 1);
          await waitFor(() => commands.length == 2);
          expect((await unwrap(commands.last))['action'], 'KEY_PRESS');
        }
        await sender.clearCard();
        await waitFor(
          () =>
              commands.last['action'] == 'CLEAR_CARD' ||
              commands.length == (password.isEmpty ? 2 : 3),
        );
        expect(await unwrap(commands.last), {'action': 'CLEAR_CARD'});
        // Only IO card state feedback, not command transmission, changes the monitor.
        expect(sender.cardStates.values.single.card, isNotNull);
        final removed = ioEvent(
          'event.cardStateChanged',
          ++sequence,
          removed: true,
        );
        agent.add(
          jsonEncode(
            password.isEmpty
                ? removed
                : await RemoteCrypto.encryptMessage(
                    password: password,
                    message: removed,
                    salt: salt,
                    messageId: '$mode-$sequence',
                  ),
          ),
        );
        await waitFor(() => sender.events.length == 4);
        expect(sender.cardStates.values.single.card, isNull);
        expect(sender.lastError, isNull);
      },
      skip: base == null,
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'Controller <-> local Relay <-> real IO DLL ($mode)',
      () async {
        final url = Uri.parse('$base-dll-$mode');
        final sender = RemoteSender(salt: salt);
        final work = await Directory.systemTemp.createTemp('controller-io-');
        final containerName =
            'controller-io-${DateTime.now().microsecondsSinceEpoch}';
        Process? process;
        final output = StringBuffer();
        addTearDown(() async {
          sender.dispose();
          if (process != null) {
            await Process.run('docker', ['rm', '-f', containerName]);
            await process.exitCode;
          }
          await work.delete(recursive: true);
        });
        await sender.connect(url: url, password: password);
        await File('${work.path}/segatools.ini').writeAsString(
          '[aimeio]\nserverUrl=${url.replace(scheme: 'ws')}\nremotePassword=$password\nautoUpdate=0\nlogLevel=warn\n',
        );
        process = await Process.start('docker', [
          'run',
          '--rm',
          '--init',
          '--network',
          'host',
          '--name',
          containerName,
          '--mount',
          'type=bind,src=${work.path},dst=/io',
          '--mount',
          'type=bind,src=$ioRoot/target/x86_64-pc-windows-gnu/release,dst=/dll,readonly',
          '--workdir',
          '/io',
          Platform.environment['HINATA_DEV_IMAGE'] ?? 'hinata-aimeio-dev:local',
          'xvfb-run',
          '-a',
          '/usr/lib/wine/wine64',
          '/dll/windows_relay_smoke.exe',
          '/dll/hinata_aimeio_rs.dll',
        ]);
        process.stdout.transform(utf8.decoder).listen(output.write);
        process.stderr.transform(utf8.decoder).listen(output.write);
        Future<void> ioWait(bool Function() ready) async {
          try {
            await waitFor(ready, timeout: const Duration(seconds: 60));
          } catch (error) {
            fail(
              '$error; ${sender.state}; ${sender.lastError}; ${sender.events.length} events\n$output',
            );
          }
        }

        await ioWait(() => sender.hello != null);
        await sender.sendCard(value: '01234567890123456789', once: false);
        await ioWait(() => sender.leds.isNotEmpty);
        await sender.clearCard();
        await ioWait(() => sender.events.length >= 4);
        final exitCode = await process.exitCode.timeout(
          const Duration(seconds: 30),
        );
        expect(exitCode, 0, reason: output.toString());
        expect(sender.events.reversed.map((event) => event.method), [
          'event.cardStateChanged',
          'event.cardConsumed',
          'event.ledSet',
          'event.cardStateChanged',
        ]);
        expect(sender.cardStates.values.single.card, isNull);
        expect(
          sender.consumedCards.values.single.params['api'],
          'aime_io_nfc_get_aime_id',
        );
        expect(sender.leds.values.single.params['r'], 17);
        expect(sender.leds.values.single.params['g'], 34);
        expect(sender.leds.values.single.params['b'], 51);
        expect(sender.missedEvents, 0);
        expect(sender.lastError, isNull);
      },
      skip: base == null || ioRoot == null,
      timeout: const Timeout(Duration(seconds: 150)),
    );
  }
}
