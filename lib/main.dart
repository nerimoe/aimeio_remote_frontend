import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AimeIO Remote',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _urlController = TextEditingController(
    text: 'https://aimeio.neri.moe/replaceMe/card',
  );
  final TextEditingController _valueController = TextEditingController();
  bool _once = false;
  bool _isLoading = false;
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('value_history') ?? [];
    });
  }

  Future<void> _addToHistory(String value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history.remove(value);
      _history.insert(0, value);
      if (_history.length > 10) {
        _history = _history.sublist(0, 10);
      }
    });
    await prefs.setStringList('value_history', _history);
  }

  Future<void> _sendRequest() async {
    if (_urlController.text.isEmpty || _valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (_valueController.text.length != 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Value must be exactly 20 digits')),
      );
      return;
    }

    _addToHistory(_valueController.text);

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse(_urlController.text);
      final body = jsonEncode({
        "type": "aime",
        "value": _valueController.text,
        "once": _once,
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Response: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        log('Error: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('AimeIO Sender'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const SizedBox(height: 20),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Access Code (20 digits)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 20,
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Once'),
              value: _once,
              onChanged: (bool value) {
                setState(() {
                  _once = value;
                });
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_valueController.text.length < 20 || _isLoading)
                  ? null
                  : _sendRequest,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send'),
            ),
            const SizedBox(height: 32),
            if (_history.isNotEmpty) ...[
              const Text(
                'History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._history.map(
                (val) => ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(val),
                  onTap: () {
                    _valueController.text = val;
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
