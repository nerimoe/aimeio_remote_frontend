# AimeIO Remote Frontend

This is a small Flutter controller and protocol example for the HINATA AimeIO Remote backend.

## Usage

1. Enter the Remote instance URL, such as `https://aime-ws.neri.moe/INSTANCE_ID`.
2. Enter a 20-character Aime access code and press **Send card**.
3. Leave the password empty to use the legacy plain Card POST format.
4. Set the same password in this app and the DLL's `[aimeio] remotePassword` setting to enable `E2EE_V1` card messages.
5. Enter a virtual key code and press count. Key commands are available only when a password is set.

Card messages are posted to the configured URL. Encrypted key commands are posted to the same instance URL with `/event` appended, so they are not stored or replayed by the relay. Key command envelopes expire after 30 seconds and use the same AES-256-GCM and PBKDF2-HMAC-SHA256 parameters as HINATA Go and the Rust DLL.

The app stores the URL, password, recent card values, key settings, and the per-instance encryption salt in local `SharedPreferences` for this test/demo workflow.

## Development

```bash
flutter pub get
flutter test
flutter analyze
```
