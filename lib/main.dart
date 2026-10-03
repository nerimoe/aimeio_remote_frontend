import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_crypto.dart';
import 'remote_keyboard.dart';
import 'remote_sender.dart';
import 'remote_monitor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final RemoteConnector? connector;

  const MyApp({super.key, this.connector});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AimeIO Remote',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(connector: connector),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final RemoteConnector? connector;

  const MyHomePage({super.key, this.connector});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const _urlCacheKey = 'url_cache';
  static const _passwordCacheKey = 'password_cache';
  static const _keyCacheKey = 'key_cache';
  static const _countCacheKey = 'count_cache';
  static const _saltCacheKey = 'encryption_salt_cache';
  static const _historyCacheKey = 'value_history';

  final TextEditingController _urlController = TextEditingController(
    text: 'https://aime-ws.neri.moe/ReplaceME',
  );
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _countController = TextEditingController();

  RemoteSender? _sender;
  bool _once = false;
  bool _passwordObscured = true;
  bool _isLoading = false;
  bool _isReady = false;
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _valueController.dispose();
    _passwordController.dispose();
    _keyController.dispose();
    _countController.dispose();
    _sender?.removeListener(_connectionChanged);
    _sender?.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final storedSalt = prefs.getString(_saltCacheKey);
    late final List<int> salt;
    try {
      salt = storedSalt == null
          ? RemoteCrypto.generateSalt()
          : RemoteCrypto.decodeSalt(storedSalt);
    } on FormatException {
      salt = RemoteCrypto.generateSalt();
    }

    final encodedSalt = RemoteCrypto.encodeSalt(salt);
    if (storedSalt != encodedSalt) {
      await prefs.setString(_saltCacheKey, encodedSalt);
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _sender = RemoteSender(salt: salt, connector: widget.connector)
        ..addListener(_connectionChanged);
      _history = prefs.getStringList(_historyCacheKey) ?? [];
      _passwordController.text = prefs.getString(_passwordCacheKey) ?? '';
      _keyController.text = prefs.getString(_keyCacheKey) ?? '32';
      _countController.text = prefs.getString(_countCacheKey) ?? '1';
      final cachedUrl = prefs.getString(_urlCacheKey);
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        _urlController.text = cachedUrl;
      }
      _isReady = true;
    });
  }

  void _connectionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlCacheKey, _urlController.text.trim());
    await prefs.setString(_passwordCacheKey, _passwordController.text);
    await prefs.setString(_keyCacheKey, _keyController.text.trim());
    await prefs.setString(_countCacheKey, _countController.text.trim());
  }

  Future<void> _connect() async {
    final sender = _sender;
    if (sender == null) return;
    try {
      final url = RemoteSender.controllerUrl(
        Uri.parse(_urlController.text.trim()),
      );
      await _savePreferences();
      if (!mounted) return;
      await sender.connect(url: url, password: _passwordController.text);
    } catch (error) {
      _showMessage('Connection error: $error');
    }
  }

  Future<void> _command(Future<void> Function() send) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _savePreferences();
      if (!mounted) return;
      await send();
      _showMessage('Sent over WebSocket. Waiting for IO events.');
    } catch (error, stackTrace) {
      log('Remote command failed', error: error, stackTrace: stackTrace);
      _showMessage('Error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendCard() async {
    if (!_canSendCard) return;
    final value = _valueController.text.trim();
    await _command(() async {
      await _sender!.sendCard(value: value, once: _once);
      if (mounted) {
        await _addToHistory(value, await SharedPreferences.getInstance());
      }
    });
  }

  Future<void> _sendKeyPress() async {
    if (!_canSendKey) return;
    await _command(
      () => _sender!.sendKeyPress(
        key: int.parse(_keyController.text.trim()),
        count: int.parse(_countController.text.trim()),
      ),
    );
  }

  Future<void> _sendKeyboardKey(int keyCode) async {
    if (!_canSendKeyboard) return;
    await _command(() => _sender!.sendKeyPress(key: keyCode, count: 1));
  }

  Future<void> _addToHistory(String value, SharedPreferences prefs) async {
    setState(() {
      _history = [
        value,
        ..._history.where((entry) => entry != value),
      ].take(10).toList();
    });
    await prefs.setStringList(_historyCacheKey, _history);
  }

  bool get _canSendCard {
    return _isReady &&
        _sender!.connected &&
        !_isLoading &&
        RegExp(r'^[0-9a-fA-F]{20}$').hasMatch(_valueController.text.trim());
  }

  bool get _canSendKey {
    final key = int.tryParse(_keyController.text.trim());
    final count = int.tryParse(_countController.text.trim());
    return _isReady &&
        _sender!.connected &&
        !_isLoading &&
        _passwordController.text.trim().isNotEmpty &&
        key != null &&
        key >= 0 &&
        key <= 0xffffffff &&
        count != null &&
        count >= 1 &&
        count <= 20;
  }

  bool get _canSendKeyboard {
    return _isReady &&
        _sender!.connected &&
        !_isLoading &&
        _passwordController.text.trim().isNotEmpty;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onFormChanged(String _) {
    setState(() {});
  }

  void _onConnectionSettingsChanged(String _) {
    _sender?.disconnect();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('AimeIO Controller'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          key: const Key('remote-page-scroll'),
          children: [
            const SizedBox(height: 20),
            TextField(
              key: const Key('remote-url'),
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Relay instance URL',
                helperText: 'HTTP(S) or WS(S); controller role is automatic',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              onChanged: _onConnectionSettingsChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('aime-value'),
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Access Code (20 characters)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 20,
              onChanged: _onFormChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('remote-password'),
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Remote password (optional)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _passwordObscured
                      ? 'Show password'
                      : 'Hide password',
                  icon: Icon(
                    _passwordObscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordObscured = !_passwordObscured;
                    });
                  },
                ),
              ),
              obscureText: _passwordObscured,
              onChanged: _onConnectionSettingsChanged,
            ),
            const SizedBox(height: 8),
            Text(
              'A password is required to use remote key and other advanced features.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            if (_sender != null) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('connect-relay'),
                      onPressed: _sender!.active
                          ? () => _sender!.disconnect()
                          : _connect,
                      icon: Icon(_sender!.active ? Icons.link_off : Icons.link),
                      label: Text(_sender!.active ? 'Disconnect' : 'Connect'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _sender!.state.name,
                    key: const Key('connection-status'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_sender!.hello != null) Text(_sender!.hello!),
              if (_sender!.lastError != null)
                Text(
                  _sender!.lastError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const Text(
                'Sent means written to the connection. IO events confirm card detection and delivery to the game.',
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Remote keyboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            RemoteKeyboard(
              enabled: _canSendKeyboard,
              onKeyPressed: _sendKeyboardKey,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('key-code'),
                    controller: _keyController,
                    decoration: const InputDecoration(
                      labelText: 'Key code',
                      helperText: 'For example, 32 is Space',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: _onFormChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('key-count'),
                    controller: _countController,
                    decoration: const InputDecoration(
                      labelText: 'Press count',
                      helperText: '1 to 20',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: _onFormChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Once'),
              value: _once,
              onChanged: _isLoading
                  ? null
                  : (bool value) {
                      setState(() {
                        _once = value;
                      });
                    },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('send-card'),
              onPressed: _canSendCard ? _sendCard : null,
              icon: const Icon(Icons.send_outlined),
              label: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send card'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const Key('send-key-press'),
              onPressed: _canSendKey ? _sendKeyPress : null,
              icon: const Icon(Icons.keyboard_alt_outlined),
              label: const Text('Press key'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('clear-card'),
              onPressed: _sender?.connected == true && !_isLoading
                  ? () => _command(() => _sender!.clearCard())
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Clear card'),
            ),
            const SizedBox(height: 24),
            if (_sender != null) RemoteMonitor(sender: _sender!),
            const SizedBox(height: 32),
            if (_history.isNotEmpty) ...[
              const Text(
                'History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._history.map(
                (value) => ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(value),
                  onTap: () {
                    setState(() {
                      _valueController.text = value;
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
