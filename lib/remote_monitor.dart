import 'dart:convert';

import 'package:flutter/material.dart';

import 'remote_events.dart';
import 'remote_sender.dart';

class RemoteMonitor extends StatelessWidget {
  final RemoteSender sender;
  const RemoteMonitor({super.key, required this.sender});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'IO feedback',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: sender.clearEvents,
              child: const Text('Clear display'),
            ),
          ],
        ),
        if (!sender.connected)
          const Text('Disconnected. Displayed feedback is historical.'),
        if (sender.missedEvents > 0)
          Text('Sequence gaps: ${sender.missedEvents} events not received.'),
        if (sender.events.isEmpty)
          const Text(
            'Waiting for IO events. Keep this Controller connected while the game polls the reader.',
          ),
        ...sender.cardStates.values.map(
          (event) => ListTile(
            key: ValueKey('card-state-${event.readerKey}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              event.card == null ? Icons.credit_card_off : Icons.credit_card,
            ),
            title: Text(
              '${event.reader}: ${event.card == null ? 'No card' : RemoteIoEvent.describeCard(event.card!)}',
            ),
            subtitle: Text(
              'Backend: ${event.params['backend'] ?? 'none'} · ${_time(event)} · Session ${event.sessionId}',
            ),
          ),
        ),
        ...sender.consumedCards.values.map(
          (event) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline),
            title: Text(
              'Last delivered: ${RemoteIoEvent.describeCard(event.card!)}',
            ),
            subtitle: Text(
              '${event.params['api']} · ${event.reader} · ${_time(event)}',
            ),
          ),
        ),
        ...sender.leds.values.map(
          (event) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              key: ValueKey('led-color-${event.readerKey}'),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: event.color,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            title: Text(event.details),
            subtitle: Text('${_time(event)} · Session ${event.sessionId}'),
          ),
        ),
        if (sender.events.isNotEmpty) ...[
          const Divider(),
          const Text('Recent events (up to 100)'),
          ...sender.events.map(
            (event) => ExpansionTile(
              key: ValueKey('event-${event.sessionId}-${event.sequence}'),
              tilePadding: EdgeInsets.zero,
              title: Text(event.title),
              subtitle: Text(
                '${_time(event)} · #${event.sequence} · ${event.details}',
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(event.params),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _time(RemoteIoEvent event) =>
      event.timestamp.toLocal().toIso8601String();
}
