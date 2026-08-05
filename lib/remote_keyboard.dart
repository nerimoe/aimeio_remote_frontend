import 'package:flutter/material.dart';

class RemoteKeyDefinition {
  final String id;
  final String label;
  final int keyCode;
  final double widthUnits;

  const RemoteKeyDefinition({
    required this.id,
    required this.label,
    required this.keyCode,
    this.widthUnits = 1.0,
  });
}

class RemoteKeyboardLayout {
  RemoteKeyboardLayout._();

  static const functionGroups = <List<RemoteKeyDefinition>>[
    [
      RemoteKeyDefinition(id: 'escape', label: 'Esc', keyCode: 0x1b),
      RemoteKeyDefinition(id: 'f1', label: 'F1', keyCode: 0x70),
      RemoteKeyDefinition(id: 'f2', label: 'F2', keyCode: 0x71),
      RemoteKeyDefinition(id: 'f3', label: 'F3', keyCode: 0x72),
      RemoteKeyDefinition(id: 'f4', label: 'F4', keyCode: 0x73),
    ],
    [
      RemoteKeyDefinition(id: 'f5', label: 'F5', keyCode: 0x74),
      RemoteKeyDefinition(id: 'f6', label: 'F6', keyCode: 0x75),
      RemoteKeyDefinition(id: 'f7', label: 'F7', keyCode: 0x76),
      RemoteKeyDefinition(id: 'f8', label: 'F8', keyCode: 0x77),
    ],
    [
      RemoteKeyDefinition(id: 'f9', label: 'F9', keyCode: 0x78),
      RemoteKeyDefinition(id: 'f10', label: 'F10', keyCode: 0x79),
      RemoteKeyDefinition(id: 'f11', label: 'F11', keyCode: 0x7a),
      RemoteKeyDefinition(id: 'f12', label: 'F12', keyCode: 0x7b),
    ],
    [
      RemoteKeyDefinition(id: 'print-screen', label: 'PrtSc', keyCode: 0x2c),
      RemoteKeyDefinition(id: 'scroll-lock', label: 'ScrLk', keyCode: 0x91),
      RemoteKeyDefinition(id: 'pause', label: 'Pause', keyCode: 0x13),
    ],
  ];

  static const mainRows = <List<RemoteKeyDefinition>>[
    [
      RemoteKeyDefinition(id: 'grave', label: '`', keyCode: 0xc0),
      RemoteKeyDefinition(id: 'digit-1', label: '1', keyCode: 0x31),
      RemoteKeyDefinition(id: 'digit-2', label: '2', keyCode: 0x32),
      RemoteKeyDefinition(id: 'digit-3', label: '3', keyCode: 0x33),
      RemoteKeyDefinition(id: 'digit-4', label: '4', keyCode: 0x34),
      RemoteKeyDefinition(id: 'digit-5', label: '5', keyCode: 0x35),
      RemoteKeyDefinition(id: 'digit-6', label: '6', keyCode: 0x36),
      RemoteKeyDefinition(id: 'digit-7', label: '7', keyCode: 0x37),
      RemoteKeyDefinition(id: 'digit-8', label: '8', keyCode: 0x38),
      RemoteKeyDefinition(id: 'digit-9', label: '9', keyCode: 0x39),
      RemoteKeyDefinition(id: 'digit-0', label: '0', keyCode: 0x30),
      RemoteKeyDefinition(id: 'minus', label: '-', keyCode: 0xbd),
      RemoteKeyDefinition(id: 'equals', label: '=', keyCode: 0xbb),
      RemoteKeyDefinition(
        id: 'backspace',
        label: 'Backspace',
        keyCode: 0x08,
        widthUnits: 2.25,
      ),
    ],
    [
      RemoteKeyDefinition(
        id: 'tab',
        label: 'Tab',
        keyCode: 0x09,
        widthUnits: 1.5,
      ),
      RemoteKeyDefinition(id: 'q', label: 'Q', keyCode: 0x51),
      RemoteKeyDefinition(id: 'w', label: 'W', keyCode: 0x57),
      RemoteKeyDefinition(id: 'e', label: 'E', keyCode: 0x45),
      RemoteKeyDefinition(id: 'r', label: 'R', keyCode: 0x52),
      RemoteKeyDefinition(id: 't', label: 'T', keyCode: 0x54),
      RemoteKeyDefinition(id: 'y', label: 'Y', keyCode: 0x59),
      RemoteKeyDefinition(id: 'u', label: 'U', keyCode: 0x55),
      RemoteKeyDefinition(id: 'i', label: 'I', keyCode: 0x49),
      RemoteKeyDefinition(id: 'o', label: 'O', keyCode: 0x4f),
      RemoteKeyDefinition(id: 'p', label: 'P', keyCode: 0x50),
      RemoteKeyDefinition(id: 'left-bracket', label: '[', keyCode: 0xdb),
      RemoteKeyDefinition(id: 'right-bracket', label: ']', keyCode: 0xdd),
      RemoteKeyDefinition(
        id: 'backslash',
        label: '\\',
        keyCode: 0xdc,
        widthUnits: 1.5,
      ),
    ],
    [
      RemoteKeyDefinition(
        id: 'caps-lock',
        label: 'Caps Lock',
        keyCode: 0x14,
        widthUnits: 1.75,
      ),
      RemoteKeyDefinition(id: 'a', label: 'A', keyCode: 0x41),
      RemoteKeyDefinition(id: 's', label: 'S', keyCode: 0x53),
      RemoteKeyDefinition(id: 'd', label: 'D', keyCode: 0x44),
      RemoteKeyDefinition(id: 'f', label: 'F', keyCode: 0x46),
      RemoteKeyDefinition(id: 'g', label: 'G', keyCode: 0x47),
      RemoteKeyDefinition(id: 'h', label: 'H', keyCode: 0x48),
      RemoteKeyDefinition(id: 'j', label: 'J', keyCode: 0x4a),
      RemoteKeyDefinition(id: 'k', label: 'K', keyCode: 0x4b),
      RemoteKeyDefinition(id: 'l', label: 'L', keyCode: 0x4c),
      RemoteKeyDefinition(id: 'semicolon', label: ';', keyCode: 0xba),
      RemoteKeyDefinition(id: 'quote', label: "'", keyCode: 0xde),
      RemoteKeyDefinition(
        id: 'enter',
        label: 'Enter',
        keyCode: 0x0d,
        widthUnits: 2.25,
      ),
    ],
    [
      RemoteKeyDefinition(
        id: 'left-shift',
        label: 'Shift',
        keyCode: 0xa0,
        widthUnits: 2.25,
      ),
      RemoteKeyDefinition(id: 'z', label: 'Z', keyCode: 0x5a),
      RemoteKeyDefinition(id: 'x', label: 'X', keyCode: 0x58),
      RemoteKeyDefinition(id: 'c', label: 'C', keyCode: 0x43),
      RemoteKeyDefinition(id: 'v', label: 'V', keyCode: 0x56),
      RemoteKeyDefinition(id: 'b', label: 'B', keyCode: 0x42),
      RemoteKeyDefinition(id: 'n', label: 'N', keyCode: 0x4e),
      RemoteKeyDefinition(id: 'm', label: 'M', keyCode: 0x4d),
      RemoteKeyDefinition(id: 'comma', label: ',', keyCode: 0xbc),
      RemoteKeyDefinition(id: 'period', label: '.', keyCode: 0xbe),
      RemoteKeyDefinition(id: 'slash', label: '/', keyCode: 0xbf),
      RemoteKeyDefinition(
        id: 'right-shift',
        label: 'Shift',
        keyCode: 0xa1,
        widthUnits: 2.75,
      ),
    ],
    [
      RemoteKeyDefinition(
        id: 'left-ctrl',
        label: 'Ctrl',
        keyCode: 0xa2,
        widthUnits: 1.25,
      ),
      RemoteKeyDefinition(
        id: 'left-win',
        label: 'Win',
        keyCode: 0x5b,
        widthUnits: 1.25,
      ),
      RemoteKeyDefinition(
        id: 'left-alt',
        label: 'Alt',
        keyCode: 0xa4,
        widthUnits: 1.25,
      ),
      RemoteKeyDefinition(
        id: 'space',
        label: 'Space',
        keyCode: 0x20,
        widthUnits: 6.25,
      ),
      RemoteKeyDefinition(
        id: 'right-alt',
        label: 'Alt',
        keyCode: 0xa5,
        widthUnits: 1.25,
      ),
      RemoteKeyDefinition(
        id: 'right-win',
        label: 'Win',
        keyCode: 0x5c,
        widthUnits: 1.25,
      ),
      RemoteKeyDefinition(
        id: 'menu',
        label: 'Menu',
        keyCode: 0x5d,
        widthUnits: 1.25,
      ),
      RemoteKeyDefinition(
        id: 'right-ctrl',
        label: 'Ctrl',
        keyCode: 0xa3,
        widthUnits: 1.25,
      ),
    ],
  ];

  static const navigationRows = <List<RemoteKeyDefinition>>[
    [
      RemoteKeyDefinition(id: 'insert', label: 'Ins', keyCode: 0x2d),
      RemoteKeyDefinition(id: 'home', label: 'Home', keyCode: 0x24),
      RemoteKeyDefinition(id: 'page-up', label: 'PgUp', keyCode: 0x21),
    ],
    [
      RemoteKeyDefinition(id: 'delete', label: 'Del', keyCode: 0x2e),
      RemoteKeyDefinition(id: 'end', label: 'End', keyCode: 0x23),
      RemoteKeyDefinition(id: 'page-down', label: 'PgDn', keyCode: 0x22),
    ],
  ];

  static const arrowRows = <List<RemoteKeyDefinition>>[
    [RemoteKeyDefinition(id: 'up', label: 'Up', keyCode: 0x26)],
    [
      RemoteKeyDefinition(id: 'left', label: 'Left', keyCode: 0x25),
      RemoteKeyDefinition(id: 'down', label: 'Down', keyCode: 0x28),
      RemoteKeyDefinition(id: 'right', label: 'Right', keyCode: 0x27),
    ],
  ];

  static const numpadRows = <List<RemoteKeyDefinition>>[
    [
      RemoteKeyDefinition(id: 'num-lock', label: 'Num', keyCode: 0x90),
      RemoteKeyDefinition(id: 'numpad-divide', label: '/', keyCode: 0x6f),
      RemoteKeyDefinition(id: 'numpad-multiply', label: '*', keyCode: 0x6a),
      RemoteKeyDefinition(id: 'numpad-subtract', label: '-', keyCode: 0x6d),
    ],
    [
      RemoteKeyDefinition(id: 'numpad-7', label: '7', keyCode: 0x67),
      RemoteKeyDefinition(id: 'numpad-8', label: '8', keyCode: 0x68),
      RemoteKeyDefinition(id: 'numpad-9', label: '9', keyCode: 0x69),
      RemoteKeyDefinition(id: 'numpad-add', label: '+', keyCode: 0x6b),
    ],
    [
      RemoteKeyDefinition(id: 'numpad-4', label: '4', keyCode: 0x64),
      RemoteKeyDefinition(id: 'numpad-5', label: '5', keyCode: 0x65),
      RemoteKeyDefinition(id: 'numpad-6', label: '6', keyCode: 0x66),
    ],
    [
      RemoteKeyDefinition(id: 'numpad-1', label: '1', keyCode: 0x61),
      RemoteKeyDefinition(id: 'numpad-2', label: '2', keyCode: 0x62),
      RemoteKeyDefinition(id: 'numpad-3', label: '3', keyCode: 0x63),
    ],
    [
      RemoteKeyDefinition(
        id: 'numpad-0',
        label: '0',
        keyCode: 0x60,
        widthUnits: 2.0,
      ),
      RemoteKeyDefinition(id: 'numpad-decimal', label: '.', keyCode: 0x6e),
      RemoteKeyDefinition(id: 'numpad-enter', label: 'Enter', keyCode: 0x0d),
    ],
  ];

  static final List<RemoteKeyDefinition> allKeys = List.unmodifiable([
    for (final group in functionGroups) ...group,
    for (final row in mainRows) ...row,
    for (final row in navigationRows) ...row,
    for (final row in arrowRows) ...row,
    for (final row in numpadRows) ...row,
  ]);
}

class RemoteKeyboard extends StatelessWidget {
  static const _keyUnit = 48.0;
  static const _keyGap = 4.0;
  static const _keyHeight = 48.0;
  static const _keyboardWidth = 1240.0;

  final bool enabled;
  final ValueChanged<int> onKeyPressed;

  const RemoteKeyboard({
    super.key,
    required this.enabled,
    required this.onKeyPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        key: const Key('remote-keyboard-scroll'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: _keyboardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFunctionRow(context),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainRows(context),
                  const SizedBox(width: 20),
                  _buildNavigationCluster(context),
                  const SizedBox(width: 20),
                  _buildNumpad(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFunctionRow(BuildContext context) {
    return Row(
      children: [
        for (
          var index = 0;
          index < RemoteKeyboardLayout.functionGroups.length;
          index++
        ) ...[
          if (index > 0) const SizedBox(width: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _buildKeyWidgets(
              context,
              RemoteKeyboardLayout.functionGroups[index],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMainRows(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in RemoteKeyboardLayout.mainRows) ...[
          _buildRow(context, row),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildNavigationCluster(BuildContext context) {
    return Column(
      children: [
        for (final row in RemoteKeyboardLayout.navigationRows) ...[
          _buildRow(context, row),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 12),
        _buildRow(context, RemoteKeyboardLayout.arrowRows[0], centered: true),
        const SizedBox(height: 6),
        _buildRow(context, RemoteKeyboardLayout.arrowRows[1]),
      ],
    );
  }

  Widget _buildNumpad(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in RemoteKeyboardLayout.numpadRows) ...[
          _buildRow(context, row),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    List<RemoteKeyDefinition> row, {
    bool centered = false,
  }) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: _buildKeyWidgets(context, row),
    );
    return centered ? Center(child: content) : content;
  }

  List<Widget> _buildKeyWidgets(
    BuildContext context,
    List<RemoteKeyDefinition> keys,
  ) {
    return [
      for (var index = 0; index < keys.length; index++) ...[
        if (index > 0) const SizedBox(width: _keyGap),
        _buildKey(context, keys[index]),
      ],
    ];
  }

  Widget _buildKey(BuildContext context, RemoteKeyDefinition definition) {
    final colorScheme = Theme.of(context).colorScheme;
    final width = definition.widthUnits * (_keyUnit + _keyGap) - _keyGap;
    final fontSize = definition.label.length > 6 ? 10.0 : 12.0;

    return SizedBox(
      width: width,
      height: _keyHeight,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: definition.label,
        child: FilledButton(
          key: Key('keyboard-key-${definition.id}'),
          onPressed: enabled ? () => onKeyPressed(definition.keyCode) : null,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            definition.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: fontSize),
          ),
        ),
      ),
    );
  }
}
