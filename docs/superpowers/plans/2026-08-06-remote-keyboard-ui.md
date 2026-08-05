# Remote Keyboard UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a complete standard Windows ANSI 104-key keyboard to the Flutter remote controller so one tap sends one encrypted `KEY_PRESS` with `count: 1`.

**Architecture:** Keep the remote protocol and `RemoteSender` unchanged. Put the typed Windows virtual-key definitions and the responsive keycap layout in `lib/remote_keyboard.dart`, then let `MyHomePage` own URL/password/loading validation and provide a callback that calls `RemoteSender.sendKeyPress`. The keyboard uses a fixed minimum width inside a horizontal scroll view, so key sizes remain stable on narrow screens.

**Tech Stack:** Flutter/Dart, Material 3, `flutter_test`, existing `http`, `cryptography`, `shared_preferences`, and `uuid` dependencies.

## Global Constraints

- Use standard Windows virtual-key values accepted by the DLL's `Key::Other` path.
- A keyboard tap always calls `RemoteSender.sendKeyPress` with `count: 1`.
- A non-empty password is required for every keyboard key; empty-password keys are disabled.
- Preserve the existing optional-password card behavior and the existing manual key-code/count controls.
- Do not change the `E2EE_V1` envelope, `/event` endpoint, backend protocol, or encryption parameters.
- Do not implement key holding, auto-repeat, modifier combinations, physical-key capture, macros, remapping, or custom layouts.
- Use stable widget keys for every keyboard key and keep the complete keyboard horizontally scrollable instead of compressing key targets below a usable size.

---

### Task 1: Define the keyboard model, layout, and keycap widget

**Files:**
- Create: `lib/remote_keyboard.dart`
- Create: `test/remote_keyboard_test.dart`

**Interfaces:**
- `RemoteKeyDefinition` is an immutable value with `id`, `label`, `keyCode`, and `widthUnits` fields.
- `RemoteKeyboardLayout.allKeys` returns the complete `List<RemoteKeyDefinition>` in visual traversal order.
- `RemoteKeyboard` accepts `bool enabled` and `ValueChanged<int> onKeyPressed` and exposes each key as `Key('keyboard-key-<id>')`.

- [ ] **Step 1: Write the failing layout tests**

Create `test/remote_keyboard_test.dart` with tests that assert the production behavior before the implementation exists:

```dart
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
          body: RemoteKeyboard(
            enabled: true,
            onKeyPressed: pressed.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('keyboard-key-space')));

    expect(pressed, [0x20]);
  });
}
```

- [ ] **Step 2: Run the layout tests and verify the expected failure**

Run:

```bash
flutter test test/remote_keyboard_test.dart
```

Expected result: the test fails because `lib/remote_keyboard.dart` and its public layout/widget interfaces do not exist yet. A missing-import failure is acceptable at this red stage; fix only test typos if the failure is unrelated.

- [ ] **Step 3: Implement the immutable key definitions**

Create `RemoteKeyDefinition` and `RemoteKeyboardLayout` in `lib/remote_keyboard.dart`. Define exactly 104 entries in these groups:

- Function/system row: Escape `0x1b`, F1-F12 `0x70..0x7b`, Print Screen `0x2c`, Scroll Lock `0x91`, Pause `0x13`.
- Main number row: grave `0xc0`, `1..0` as ASCII `0x31..0x30`, minus `0xbd`, equals `0xbb`, Backspace `0x08`.
- QWERTY row: Tab `0x09`, Q-P as ASCII, left bracket `0xdb`, right bracket `0xdd`, backslash `0xdc`.
- Home row: Caps Lock `0x14`, A-L as ASCII, semicolon `0xba`, quote `0xde`, Enter `0x0d`.
- Bottom letter row: left Shift `0xa0`, Z-M as ASCII, comma `0xbc`, period `0xbe`, slash `0xbf`, right Shift `0xa1`.
- Modifier row: left Ctrl `0xa2`, left Win `0x5b`, left Alt `0xa4`, Space `0x20`, right Alt `0xa5`, right Win `0x5c`, Menu `0x5d`, right Ctrl `0xa3`.
- Navigation cluster: Insert `0x2d`, Home `0x24`, Page Up `0x21`, Delete `0x2e`, End `0x23`, Page Down `0x22`, and Left/Up/Down/Right `0x25/0x26/0x28/0x27`.
- Numeric keypad: Num Lock `0x90`, Divide `0x6f`, Multiply `0x6a`, Subtract `0x6d`, Add `0x6b`, Numpad 7-9 `0x67..0x69`, 4-6 `0x64..0x66`, 1-3 `0x61..0x63`, Numpad 0 `0x60`, Decimal `0x6e`, and keypad Enter `0x0d`.

Use readable IDs such as `escape`, `f1`, `left-shift`, `space`, `page-up`, and `numpad-0`; IDs must be unique even when two physical keys share a virtual-key code. Use width units of `1.0` for normal keys, `1.25` for standard modifiers, `2.25` for Backspace/Enter/Shift, `1.5` for Tab, and `6.25` for Space.

- [ ] **Step 4: Implement the stable, scrollable keyboard widget**

In the same file, build `RemoteKeyboard` with:

- A horizontal `SingleChildScrollView` keyed as `remote-keyboard-scroll`.
- A child with a minimum/stable width of approximately `1060.0` logical pixels.
- Function row, main rows, navigation block, arrow cluster, and numeric keypad rendered as distinct groups using the layout definitions.
- A keycap button sized from `widthUnits`, with a stable height of `48.0`, small rectangular corners, readable labels, and disabled styling from the current `ColorScheme`.
- `onPressed: enabled ? () => onKeyPressed(definition.keyCode) : null` so the widget itself cannot emit a key while disabled and cannot emit more than one callback for one tap.
- Stable keys `keyboard-key-<id>` on the actual tappable buttons and semantics labels based on the displayed key label.

- [ ] **Step 5: Run the layout tests and verify they pass**

Run:

```bash
dart format lib/remote_keyboard.dart test/remote_keyboard_test.dart
flutter test test/remote_keyboard_test.dart
```

Expected result: all layout, representative-code, and single-tap tests pass.

- [ ] **Step 6: Commit the self-contained keyboard component**

```bash
git add lib/remote_keyboard.dart test/remote_keyboard_test.dart
git commit -m "feat(remote): add complete keyboard layout"
```

### Task 2: Wire keyboard taps into the remote page

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- `MyHomePage` imports `remote_keyboard.dart` and passes `_canSendKeyboard` plus `_sendKeyboardKey` to `RemoteKeyboard`.
- `_sendKeyboardKey(int keyCode)` validates the configured URL/password/readiness/loading state, persists the selected key and count `1`, and delegates to `RemoteSender.sendKeyPress(..., key: keyCode, count: 1, ...)`.

- [ ] **Step 1: Add failing page tests for disabled/enabled keyboard behavior**

Extend `test/widget_test.dart` with these behaviors:

```dart
testWidgets('disables the complete keyboard until a password is set', (tester) async {
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
    tester.widget<FilledButton>(
      find.byKey(const Key('keyboard-key-space')),
    ).onPressed,
    isNotNull,
  );
});
```

Add a recording HTTP client in the test file, pump `MyApp(httpClient: client)`, enter the password, tap `keyboard-key-space`, and await `tester.pumpAndSettle()`. Decode the one request body with `RemoteCrypto.decryptMessage` and assert its inner message is `{'action': 'KEY_PRESS', 'body': {'key': 0x20, 'count': 1}}` and its URL ends in `/event`.

- [ ] **Step 2: Run the page tests and verify the new tests fail for the missing keyboard integration**

Run:

```bash
flutter test test/widget_test.dart
```

Expected result: the existing page tests pass or reach their existing assertions, while the new keyboard assertions fail because `MyHomePage` does not yet render the keyboard or connect its callback.

- [ ] **Step 3: Add the page-level keyboard send path**

Import `remote_keyboard.dart` in `lib/main.dart`. Add:

```dart
bool get _canSendKeyboard {
  return _isReady &&
      !_isLoading &&
      _passwordController.text.trim().isNotEmpty;
}
```

Implement `_sendKeyboardKey(int keyCode)` using the existing `_salt`, URL parsing, SnackBar validation, `SharedPreferences`, loading guard, and error logging. It must call `sendKeyPress` with `count: 1` and must never call the legacy card endpoint. Keep `_sendKeyPress` for the existing manual key-code/count form; factor shared URL/password/request cleanup only after the new tests are green.

- [ ] **Step 4: Render the keyboard in the page**

Place a compact `Keyboard` section after the password warning and before the existing manual key-code/count controls. Render:

```dart
const Text('Remote keyboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
const SizedBox(height: 8),
RemoteKeyboard(
  enabled: _canSendKeyboard,
  onKeyPressed: _sendKeyboardKey,
),
```

Keep the existing manual controls, card controls, history behavior, and loading state. Ensure the page's single `_isLoading` state disables both the keyboard and the existing send buttons while a request is in flight.

- [ ] **Step 5: Run focused page tests and verify the integration passes**

Run:

```bash
dart format lib/main.dart test/widget_test.dart
flutter test test/widget_test.dart
```

Expected result: the password gate test, full keyboard request test, and existing card/key control tests pass. The recorded request must contain `count: 1` even if the manual count field has another value.

- [ ] **Step 6: Commit the page integration**

```bash
git add lib/main.dart test/widget_test.dart
git commit -m "feat(remote): wire keyboard taps to key events"
```

### Task 3: Document and verify the complete feature

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the README usage flow**

Keep the existing encryption and endpoint documentation, and add that the app presents a complete Windows ANSI keyboard. State that each keyboard tap sends one key event, keyboard controls remain disabled until a remote password is configured, and the manual key-code/count controls remain available for protocol testing.

- [ ] **Step 2: Run formatting and the complete test suite**

Run:

```bash
dart format lib/main.dart lib/remote_keyboard.dart test/widget_test.dart test/remote_keyboard_test.dart
flutter test
```

Expected result: all Flutter tests pass with no test errors or warnings.

- [ ] **Step 3: Run static analysis and whitespace checks**

Run:

```bash
flutter analyze
git diff --check
```

Expected result: `flutter analyze` reports no issues and `git diff --check` produces no output.

- [ ] **Step 4: Inspect the final diff and commit documentation**

Confirm the diff contains no protocol changes, no password/ciphertext logging, and no generated files outside the requested feature. Then commit:

```bash
git add README.md
git commit -m "docs: document remote keyboard controls"
```

- [ ] **Step 5: Confirm repository state**

Run:

```bash
git status --short --branch
git log -4 --oneline
```

Expected result: the working tree is clean and the three feature commits are visible on `main`.
