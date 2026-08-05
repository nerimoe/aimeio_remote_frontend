import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aimeio_remote_frontend/remote_keyboard.dart';

void main() {
  test('defines all 104 ANSI keyboard keys with stable identifiers', () {
    final keys = RemoteKeyboardLayout.allKeys;
    final ids = keys.map((key) => key.id).toSet();

    expect(keys, hasLength(104));
    expect(ids, hasLength(keys.length));
    expect(keys.every((key) => key.keyCode > 0), isTrue);
  });

  test('uses representative Windows virtual-key values', () {
    RemoteKeyDefinition key(String id) =>
        RemoteKeyboardLayout.allKeys.firstWhere((item) => item.id == id);

    expect(key('escape').keyCode, 0x1b);
    expect(key('a').keyCode, 0x41);
    expect(key('space').keyCode, 0x20);
    expect(key('left').keyCode, 0x25);
    expect(key('numpad-0').keyCode, 0x60);
  });

  testWidgets('tapping a key invokes the callback once', (tester) async {
    final pressed = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemoteKeyboard(enabled: true, onKeyPressed: pressed.add),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('keyboard-key-space')));

    expect(pressed, [0x20]);
  });
}
