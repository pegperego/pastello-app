import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Asks a grown-up to solve a random two-digit addition (decision D-08).
///
/// Returns `true` only if the answer is right. A wrong answer asks a new
/// question. The gate must be passed again every time it is shown.
Future<bool> showParentalGate(BuildContext context, {Random? random}) async {
  final passed = await showDialog<bool>(
    context: context,
    builder: (_) => ParentalGateDialog(random: random ?? Random()),
  );
  return passed ?? false;
}

/// The dialog shown by [showParentalGate].
class ParentalGateDialog extends StatefulWidget {
  const ParentalGateDialog({super.key, required this.random});

  final Random random;

  @override
  State<ParentalGateDialog> createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends State<ParentalGateDialog> {
  late int _a;
  late int _b;
  String _answer = '';

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  void _newQuestion() {
    // Two-digit numbers with a carry, too hard for an 8-year-old to guess
    // by chance and quick for an adult.
    _a = 21 + widget.random.nextInt(58);
    _b = 21 + widget.random.nextInt(58);
    _answer = '';
  }

  void _type(String digit) {
    if (_answer.length < 3) setState(() => _answer += digit);
  }

  void _backspace() {
    if (_answer.isNotEmpty) {
      setState(() => _answer = _answer.substring(0, _answer.length - 1));
    }
  }

  void _confirm() {
    if (int.tryParse(_answer) == _a + _b) {
      Navigator.of(context).pop(true);
    } else {
      setState(_newQuestion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget key(String label, VoidCallback onPressed, {Color? color}) => Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 88,
        height: Tokens.minTouchTarget,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color ?? Tokens.paper,
            foregroundColor: color == null ? Tokens.ink : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: fredoka(22, weight: FontWeight.w500),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );

    return AlertDialog(
      backgroundColor: Tokens.sheet,
      title: Text(
        l10n.grownUpsOnly,
        textAlign: TextAlign.center,
        style: fredoka(18, weight: FontWeight.w500),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.gateQuestion(_a, _b), style: fredoka(36)),
          const SizedBox(height: 12),
          Container(
            width: 280,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Tokens.border, width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(_answer, style: fredoka(28)),
          ),
          const SizedBox(height: 12),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final d in row) key(d, () => _type(d))],
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: l10n.deleteDigit,
                excludeSemantics: true,
                child: key('⌫', _backspace),
              ),
              key('0', () => _type('0')),
              Semantics(
                label: l10n.confirm,
                excludeSemantics: true,
                child: key('✓', _confirm, color: Tokens.mint),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
