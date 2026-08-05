import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aimeio_remote_frontend/main.dart';

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
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('send-key-press')))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('remote-password')),
      'test-remote-password',
    );
    await tester.pump();

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
    expect(find.byKey(const Key('key-code')), findsOneWidget);
    expect(find.byKey(const Key('key-count')), findsOneWidget);
    expect(find.byKey(const Key('send-card')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('send-key-press')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('send-key-press')), findsOneWidget);
  });
}
