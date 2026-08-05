import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_crypto.dart';
import 'remote_sender.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final http.Client? httpClient;

  const MyApp({super.key, this.httpClient});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AimeIO Remote',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(httpClient: httpClient),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final http.Client? httpClient;

  const MyHomePage({super.key, this.httpClient});

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

  late final http.Client _httpClient;
  late final bool _ownsHttpClient;
  List<int>? _salt;
  bool _once = false;
  bool _passwordObscured = true;
  bool _isLoading = false;
  bool _isReady = false;
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    final suppliedClient = widget.httpClient;
    _ownsHttpClient = suppliedClient == null;
    _httpClient = suppliedClient ?? http.Client();
    _loadPreferences();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _valueController.dispose();
    _passwordController.dispose();
    _keyController.dispose();
    _countController.dispose();
    if (_ownsHttpClient) {
      _httpClient.close();
    }
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
      _salt = salt;
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

  Future<void> _sendCard() async {
    if (!_canSendCard) {
      return;
    }
    final salt = _salt;
    if (salt == null) {
      return;
    }

    final value = _valueController.text.trim();
    final url = Uri.tryParse(_urlController.text.trim());
    if (url == null || !_isHttpUrl(url)) {
      _showMessage('Please enter a valid HTTP or HTTPS URL');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_urlCacheKey, url.toString());
      await prefs.setString(_passwordCacheKey, _passwordController.text.trim());
      await prefs.setString(_keyCacheKey, _keyController.text.trim());
      await prefs.setString(_countCacheKey, _countController.text.trim());
      await _addToHistory(value, prefs);

      final response = await RemoteSender(client: _httpClient, salt: salt)
          .sendCard(
            url: url,
            value: value,
            once: _once,
            password: _passwordController.text.trim(),
          );
      _showMessage('Response: ${response.statusCode}');
    } catch (e, stackTrace) {
      log('Card request failed: $e', stackTrace: stackTrace);
      _showMessage('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendKeyPress() async {
    if (!_canSendKey) {
      if (_passwordController.text.trim().isEmpty) {
        _showMessage(
          'A password is required to use remote key and other advanced features.',
        );
      }
      return;
    }
    final salt = _salt;
    if (salt == null) {
      return;
    }

    final url = Uri.tryParse(_urlController.text.trim());
    final key = int.tryParse(_keyController.text.trim());
    final count = int.tryParse(_countController.text.trim());
    if (url == null || !_isHttpUrl(url)) {
      _showMessage('Please enter a valid HTTP or HTTPS URL');
      return;
    }
    if (key == null || key < 0 || key > 0xffffffff) {
      _showMessage('Key code must fit in an unsigned 32-bit integer');
      return;
    }
    if (count == null || count < 1 || count > 20) {
      _showMessage('Key press count must be between 1 and 20');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_urlCacheKey, url.toString());
      await prefs.setString(_passwordCacheKey, _passwordController.text.trim());
      await prefs.setString(_keyCacheKey, key.toString());
      await prefs.setString(_countCacheKey, count.toString());

      final response = await RemoteSender(client: _httpClient, salt: salt)
          .sendKeyPress(
            url: url,
            key: key,
            count: count,
            password: _passwordController.text.trim(),
          );
      _showMessage('Response: ${response.statusCode}');
    } catch (e, stackTrace) {
      log('Key request failed: $e', stackTrace: stackTrace);
      _showMessage('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
    return _isReady && !_isLoading && _valueController.text.trim().length == 20;
  }

  bool get _canSendKey {
    final key = int.tryParse(_keyController.text.trim());
    final count = int.tryParse(_countController.text.trim());
    return _isReady &&
        !_isLoading &&
        _passwordController.text.trim().isNotEmpty &&
        key != null &&
        key >= 0 &&
        key <= 0xffffffff &&
        count != null &&
        count >= 1 &&
        count <= 20;
  }

  bool _isHttpUrl(Uri url) {
    return (url.scheme == 'http' || url.scheme == 'https') &&
        url.host.isNotEmpty;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('AimeIO Sender'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 20),
            TextField(
              key: const Key('remote-url'),
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              onChanged: _onFormChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('aime-value'),
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Access Code (20 digits)',
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
              onChanged: _onFormChanged,
            ),
            const SizedBox(height: 8),
            Text(
              'A password is required to use remote key and other advanced features.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
