import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aimeio_remote_frontend/main.dart';
import 'package:aimeio_remote_frontend/remote_crypto.dart';

import 'fake_channel.dart';

Finder _pageScrollable() => find
    .descendant(
      of: find.byKey(const Key('remote-page-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> showControl(
  WidgetTester tester,
  String key, {
  double delta = 250,
}) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    delta,
    scrollable: _pageScrollable(),
  );
  await tester.pumpAndSettle();
}

void main() {
  late FakeChannel channel;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    channel = FakeChannel();
  });

  Future<void> load(WidgetTester tester, {bool password = false}) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MyApp(connector: (_) => channel));
    await tester.pumpAndSettle();
    if (password) {
      await tester.enterText(
        find.byKey(const Key('remote-password')),
        'test-remote-password',
      );
    }
  }

  Future<void> connect(WidgetTester tester) async {
    await showControl(tester, 'connect-relay', delta: -250);
    await tester.tap(find.byKey(const Key('connect-relay')));
    await tester.pumpAndSettle();
  }

  testWidgets('requires connection and password before enabling keyboard', (
    tester,
  ) async {
    await load(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('keyboard-key-space')))
          .onPressed,
      isNull,
    );
    await connect(tester);
    expect(find.text('connected'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('keyboard-key-space')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('remote-password')),
      'test-remote-password',
    );
    await tester.pumpAndSettle();
    expect(find.text('disconnected'), findsOneWidget);
    // Editing the password closes the old socket; use a fresh fake connection.
    channel = FakeChannel();
    await connect(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('keyboard-key-space')))
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('renders card, clear, key controls and feedback', (tester) async {
    await load(tester);
    expect(find.byKey(const Key('remote-url')), findsOneWidget);
    expect(find.byKey(const Key('aime-value')), findsOneWidget);
    for (final key in [
      'key-code',
      'key-count',
      'send-card',
      'send-key-press',
      'clear-card',
    ]) {
      await showControl(tester, key);
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.text('IO feedback'),
      250,
      scrollable: _pageScrollable(),
    );
    expect(find.text('IO feedback'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sends one encrypted key on the persistent connection', (
    tester,
  ) async {
    await load(tester, password: true);
    await connect(tester);
    await showControl(tester, 'keyboard-key-space');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('keyboard-key-space')));
      await waitFor(() => channel.sent.isNotEmpty);
    });
    await tester.pumpAndSettle();
    expect(channel.sent.length, 1);
    final message = await tester.runAsync(
      () => RemoteCrypto.decryptMessage(
        password: 'test-remote-password',
        envelope: channel.sent.single,
      ),
    );
    expect(message, {
      'action': 'KEY_PRESS',
      'body': {'key': 0x20, 'count': 1},
    });
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows detection, game delivery and LED feedback independently', (
    tester,
  ) async {
    await load(tester);
    await connect(tester);
    channel.receive(ioEvent('event.cardStateChanged', 1));
    channel.receive(ioEvent('event.cardConsumed', 2));
    channel.receive(ioEvent('event.ledSet', 3));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('IO feedback'),
      350,
      scrollable: _pageScrollable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('aimeio / 0: aime 01234567890123456789'), findsOneWidget);
    expect(
      find.text('Last delivered: aime 01234567890123456789'),
      findsOneWidget,
    );
    final color = tester.widget<Container>(
      find.byKey(const ValueKey('led-color-io-session/aimeio / 0')),
    );
    expect(
      (color.decoration as BoxDecoration).color,
      const Color.fromARGB(255, 255, 34, 51),
    );
    channel.receive(ioEvent('event.cardStateChanged', 4, removed: true));
    await tester.pumpAndSettle();
    expect(find.text('aimeio / 0: No card'), findsOneWidget);
    expect(
      find.text('Last delivered: aime 01234567890123456789'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'sends card and clear without password and validates access code',
    (tester) async {
      await load(tester);
      await tester.enterText(
        find.byKey(const Key('aime-value')),
        '01234567890123456789',
      );
      await connect(tester);
      await showControl(tester, 'send-card');
      await tester.tap(find.byKey(const Key('send-card')));
      await tester.pumpAndSettle();
      expect(channel.sent.single['action'], 'SET_CARD');
      expect(
        find.text('Sent over WebSocket. Waiting for IO events.'),
        findsOneWidget,
      );
      await showControl(tester, 'clear-card');
      await tester.tap(find.byKey(const Key('clear-card')));
      await tester.pumpAndSettle();
      expect(channel.sent.last, {'action': 'CLEAR_CARD'});
      await tester.pumpWidget(const SizedBox());
    },
  );
}
