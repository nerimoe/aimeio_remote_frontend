# AimeIO Remote Frontend

Flutter Controller / protocol demo for HINATA AimeIO Remote and the
[aimeio-backend-ws](https://github.com/nerimoe/aimeio-backend-ws) Relay.

## Usage

1. Enter the Relay instance URL, for example `https://aime-ws.neri.moe/INSTANCE_ID`
   or `ws://127.0.0.1:8787/INSTANCE_ID`. HTTP(S) addresses are converted to WS(S).
   The app connects with `role=controller&card_protocol=2` automatically.
2. Enter the same password as the IO DLL's `[aimeio] remotePassword`, or leave
   both empty for plaintext card commands and IO feedback. Click **Connect**.
   Opening the app does not connect to the example server automatically.
3. Enter a 20-character Aime Access Code and click **Send card**. **Once** preserves
   the existing disposable-card behavior. Use **Clear card** to remove the Remote card.
4. The Windows ANSI 104-key keyboard and key-code/count controls require a
   password and an active Relay connection. Each keyboard tap sends one key press.
5. Watch **IO feedback** for card detection/removal, successful delivery to the
   game, and RGB colors requested by the game. Expand a recent event to inspect
   its full payload, including backend, source, interface, unit, session and sequence.

Configure IO with the same room and password:

```ini
[aimeio]
serverUrl=https://aime-ws.neri.moe/INSTANCE_ID
remotePassword=YOUR_PASSWORD
```

All commands and feedback now use one persistent WebSocket; the app no longer
POSTs to the room or `/event`. URL/password edits disconnect the old session and
require **Connect** again. Unexpected disconnects retry with increasing delays.
Commands are never queued or automatically replayed after reconnecting. Relay's
WebSocket route forwards messages without storing them as HTTP state: a card
sent through this app is not replayed to a newly connected IO agent.

**Sent** means the command was written to the WebSocket, not acknowledged by IO.
A connected Relay socket alone does not prove an IO agent is online. IO sends
`CLIENT_HELLO` when it connects; if IO was already online when the Controller
connected, wait for its next event or reconnect IO to see that hello. The Relay
does not replay hello or past feedback to a new Controller. Card state events
reflect the result selected by game polling, including all backend types; no
polling means no card-state report. Successful delivery is not proof of game login.

## IO event protocol 1

The app handles these JSON-RPC notifications independently:

| Method | Display |
| --- | --- |
| `event.cardStateChanged` | Latest card snapshot and selected backend per IO session/interface/unit; `card: null` means removal |
| `event.cardConsumed` | Last card delivered to the game and the API used; independent of the current card state |
| `event.ledSet` | Latest raw RGB value and color swatch per reader |

The latest 100 events are retained in memory. Events are deduplicated using
`(session_id, sequence)`; sequence gaps are counted when a later event arrives.
The first event for a session establishes the baseline. Disconnects show the
existing feedback as historical. **Clear display** clears the monitor without
sending a card command. A new manual connection clears the display as well.
The Relay and IO use bounded, nonpersistent event queues: this demo cannot recover
feedback lost during disconnections or while no Controller was present.

With a password, outgoing card/clear/key commands use the existing `E2EE_V1`
AES-256-GCM / PBKDF2-HMAC-SHA256 (600,000 iterations) format. Key envelopes expire
in 30 seconds. Incoming IO events are decrypted in wire order, authenticated,
checked for expiration, and deduplicated. Plaintext feedback is rejected when a
password is configured; the plaintext capability advertisement `CLIENT_HELLO`
is allowed. Failed decryption is shown as a receive error and later messages
continue to be processed. Encryption parameters and the shared Rust/Dart test
vector are unchanged.

The app retains its demo behavior of storing the URL, password, recent Access
Codes, key settings and encryption salt in local `SharedPreferences`. Event
history is not persisted. Earlier design documents under `docs/superpowers/`
describe the previous HTTP implementation, rather than the current transport.

## Development

Use Flutter **3.38.5** / Dart **3.10.4** (pinned in `.flutter-version`).

```bash
flutter pub get --enforce-lockfile
flutter run -d chrome
./tools/check.sh
```

`tools/check.sh` checks formatting, runs static analysis and tests, then builds
`build/web`. CI runs the same checks. On an HTTPS page use a `wss://` Relay URL;
browsers normally block an insecure WebSocket from an HTTPS page.

### Local Relay integration

Install the dependencies in the sibling Relay repository first:

```bash
cd ../aimeio-backend-ws
bun install --frozen-lockfile
cd ../aimeio_remote_frontend
node tools/relay-smoke.mjs ../aimeio-backend-ws
```

This requires Node 22+ and `flutter` on PATH (`FLUTTER_BIN` can select another
Flutter executable). It starts a temporary local Wrangler Worker and tests the
actual Dart Controller transport against an Agent socket, in plaintext and
password modes: card/clear/key commands, hello, card state/consumption/LED feedback,
and removal. It cleans up the Worker and temporary Durable Object data afterward.
These integration tests are skipped by ordinary `flutter test` unless
`RELAY_TEST_URL` is set.

For the complete **Flutter Controller → Relay → real Windows IO DLL → Relay →
Controller** loop under Linux, use the previously configured
`hinata-aimeio-rs` development image and build its x64 DLL / C fixture with its
`tools/relay-smoke.sh` once. Then:

```bash
AIMEIO_ROOT=/absolute/path/to/hinata-aimeio-rs \
  node tools/relay-smoke.mjs ../aimeio-backend-ws
```

This adds plaintext and encrypted real-DLL tests. Docker/Wine use host networking
only to reach the temporary local Relay; no production room or physical reader is
used. `HINATA_DEV_IMAGE` can override `hinata-aimeio-dev:local`. The DLL fixture
reads a card repeatedly, sets RGB 17/34/51 and waits for removal. The tests require
exactly one consumption event and a state → consumption → LED → removal sequence.
