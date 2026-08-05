# Remote E2EE and Key Command Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the example Flutter controller with protocol-compatible optional Remote encryption and an encrypted key-press event command.

**Architecture:** Keep the page responsible for input and user feedback, move AES-256-GCM/PBKDF2/envelope construction into `RemoteCrypto`, and move HTTP request construction into `RemoteSender`. The sender keeps legacy bare-card POST behavior when the password is empty; encrypted card messages use the state endpoint and encrypted key messages use the `/event` endpoint.

**Tech Stack:** Flutter/Dart, `http`, `cryptography`, `uuid`, `shared_preferences`, `flutter_test`.

## Global Constraints

- Preserve legacy bare Card JSON when the password is empty.
- Use `E2EE_V1`, AES-256-GCM, PBKDF2-HMAC-SHA256 with 600000 iterations, 16-byte salt, 12-byte nonce, URL-safe base64 without padding, and the existing AAD string.
- Use a UUIDv4 `message_id` for every encrypted message.
- Key events must use `/event`, include an `expires_at` timestamp, and accept only `count` values from 1 through 20.
- Never log the password or ciphertext payload.

### Task 1: Add the protocol crypto dependency and failing crypto tests

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `lib/remote_crypto.dart`
- Create: `test/remote_crypto_test.dart`

**Interfaces:**
- Produce `RemoteCrypto.generateSalt()` and `RemoteCrypto.encodeSalt`/`RemoteCrypto.decodeSalt` for a persisted 16-byte per-endpoint salt.
- Produce `RemoteCrypto.encryptMessage({required String password, required Map<String, dynamic> message, required String messageId, required List<int> salt, int? expiresAt, List<int>? nonce})` returning `Future<Map<String, dynamic>>`.
- Produce `RemoteCrypto.decryptMessage({required String password, required Map<String, dynamic> envelope})` returning `Future<Map<String, dynamic>>` for test and cross-language verification.

- [x] Add `cryptography` and `uuid` dependencies.
- [x] Write tests for the fixed Rust/Dart-compatible vector, wrong-password rejection, and encrypted `SET_CARD` field shape.
- [x] Run `flutter test test/remote_crypto_test.dart`; it failed because `RemoteCrypto` did not exist.
- [x] Implement only the crypto helper needed by those tests.
- [x] Run the targeted tests again and require a pass.

### Task 2: Add request construction and failing sender tests

**Files:**
- Create: `lib/remote_sender.dart`
- Create: `test/remote_sender_test.dart`

**Interfaces:**
- `RemoteSender({http.Client? client, required List<int> salt})` owns the injectable HTTP client and the persisted per-endpoint salt.
- `Future<http.Response> sendCard({required Uri url, required String value, required bool once, String password = ''})` sends either a legacy Card body or an encrypted `SET_CARD` message.
- `Future<http.Response> sendKeyPress({required Uri url, required int key, required int count, required String password})` posts an encrypted `KEY_PRESS` message to `url.replace(path: '${url.path.replaceFirst(RegExp(r'/$'), '')}/event')`, preserving the configured instance path.

- [x] Write tests for legacy card body, encrypted card body, encrypted key endpoint, expiration, and invalid password/count rejection.
- [x] Run `flutter test test/remote_sender_test.dart`; it failed before the sender existed.
- [x] Implement sender request construction using `RemoteCrypto` and a fresh UUID for each message.
- [x] Run the targeted tests and require a pass.

### Task 3: Wire password and key controls into the page

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

- [x] Add password, key code, count, and per-endpoint encryption-salt controllers/state plus persistence keys for password/key/count/salt.
- [x] Add password visibility control and a warning that encrypted password is required for advanced key functionality.
- [x] Add a numeric key-code field, count field bounded to 1..20, and a separate key-press button.
- [x] Disable key sending without a password and show validation feedback for URL, password, key, count, and Aime value.
- [x] Route card send through `RemoteSender.sendCard` and key send through `RemoteSender.sendKeyPress`.
- [x] Keep loading state scoped so duplicate requests cannot be submitted.
- [x] Replace the generated counter smoke test with widget tests for the password-required key action and card/key controls.
- [x] Run the widget tests and require a pass.

### Task 4: Update documentation and run the full verification suite

**Files:**
- Modify: `README.md`

- [x] Document the optional password, the same-password requirement with DLL, the encrypted card envelope, and the `/event` key endpoint.
- [x] Run `dart format` on changed Dart files.
- [x] Run `flutter test`.
- [x] Run `flutter analyze` with no issues found.
- [x] Run `git diff --check` and inspect the final diff for plaintext password/ciphertext logging.
