import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aimeio_remote_frontend/main.dart';
import 'package:aimeio_remote_frontend/remote_crypto.dart';

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

Finder _pageScrollable() {
  return find
      .descendant(
        of: find.byKey(const Key('remote-page-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('requires a password before enabling key press', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'A password is required to use remote key and other advanced features.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('send-key-press')),
      300,
      scrollable: _pageScrollable(),
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('send-key-press')))
          .onPressed,
      isNull,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('remote-password')),
      -300,
      scrollable: _pageScrollable(),
    );
    await tester.enterText(
      find.byKey(const Key('remote-password')),
      'test-remote-password',
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('send-key-press')),
      300,
      scrollable: _pageScrollable(),
    );

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('send-key-press')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('renders card and key command controls', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('remote-url')), findsOneWidget);
    expect(find.byKey(const Key('aime-value')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('key-code')),
      300,
      scrollable: _pageScrollable(),
    );
    expect(find.byKey(const Key('key-code')), findsOneWidget);
    expect(find.byKey(const Key('key-count')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('send-card')),
      300,
      scrollable: _pageScrollable(),
    );
    expect(find.byKey(const Key('send-card')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('send-key-press')),
      300,
      scrollable: _pageScrollable(),
    );
    expect(find.byKey(const Key('send-key-press')), findsOneWidget);
  });

  testWidgets('disables the complete keyboard until a password is set', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final space = tester.widget<FilledButton>(
      find.byKey(const Key('keyboard-key-space')),
    );
    expect(space.onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('remote-password')),
      'test-remote-password',
    );
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('keyboard-key-space')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('sends one encrypted event when a keyboard key is tapped', (
    tester,
  ) async {
    final client = RecordingClient();
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MyApp(httpClient: client));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('remote-password')),
      'test-remote-password',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('keyboard-key-space')));
    await tester.pumpAndSettle();

    expect(client.requests, hasLength(1));
    final request = client.requests.single as http.Request;
    final envelope = jsonDecode(request.body) as Map<String, dynamic>;
    final message = await RemoteCrypto.decryptMessage(
      password: 'test-remote-password',
      envelope: envelope,
    );

    expect(request.url.toString(), 'https://aime-ws.neri.moe/ReplaceME/event');
    expect(message, {
      'action': 'KEY_PRESS',
      'body': {'key': 0x20, 'count': 1},
    });
  });
}
