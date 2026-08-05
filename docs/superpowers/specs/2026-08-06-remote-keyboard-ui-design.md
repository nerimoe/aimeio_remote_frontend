# Remote Keyboard UI Design

## Goal

Add a complete standard Windows ANSI 104-key keyboard to the Flutter remote
controller. A single tap on a key sends exactly one encrypted `KEY_PRESS`
message with `count: 1` to the configured remote instance.

## Scope

- Keep the existing URL, password, loading, validation, and `RemoteSender`
  request flow.
- Add a reusable keyboard widget backed by typed key definitions rather than
  hard-coded button callbacks.
- Cover the standard ANSI keyboard groups:
  - Escape and F1-F12 function keys
  - Main alphanumeric section, punctuation, modifiers, and space bar
  - Print Screen, Scroll Lock, Pause, navigation cluster, and arrow keys
  - Numeric keypad, including Num Lock, arithmetic keys, navigation digits,
    decimal, and keypad Enter
- Use Windows virtual-key values compatible with the DLL's `Key::Other` input
  path. Duplicate physical keys such as left/right Shift use their distinct
  Windows virtual-key values where available; keys whose protocol uses one
  virtual-key value may share that value.
- Require a non-empty password. When the password is empty, every keyboard key
  is disabled and the existing password warning remains the user-facing reason.
- When a key is tapped, invoke the existing sender with `count: 1`; the UI does
  not implement key holding, auto-repeat, or modifier combinations.

## Layout

The keyboard is a dedicated widget with three visual regions:

1. Function row: Escape, F1-F12, and the three system keys.
2. Main area: number row, QWERTY rows, modifiers, space bar, and navigation
   cluster.
3. Numeric keypad: Num Lock, arithmetic operators, digits, decimal, and Enter.

The keyboard keeps stable key dimensions and uses a minimum content width. On
narrow windows or phones the complete keyboard is horizontally scrollable rather
than compressing keys below a comfortable touch target. Key buttons use modest
rectangular keycap styling, with wider buttons represented by a width unit.

## Data flow

`KeyboardPanel` receives the current enabled state and an `onKeyPressed(int)`
callback from the page. The page checks URL/password/readiness/loading state and
calls `RemoteSender.sendKeyPress(url: ..., key: key, count: 1, password: ...)`.
The page preserves the existing request error SnackBar and prevents concurrent
requests through its loading state.

## Testing

- Unit-test the keyboard definition table for complete key coverage, unique
  widget identifiers, and representative Windows virtual-key values.
- Widget-test that all keyboard regions render, an empty password disables a key,
  and a configured password enables it.
- Widget-test a representative key tap and verify the page invokes the sender
  through the existing HTTP path with `count: 1` and the expected key value.
- Run `dart format`, `flutter test`, `flutter analyze`, and `git diff --check`.

## Non-goals

- No change to the remote envelope or backend protocol.
- No physical keyboard event capture.
- No key-down/key-up state, macro recording, remapping, or custom layouts.
