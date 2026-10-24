import 'package:flutter/material.dart';

import '../../../app/tokens.dart';

/// The field where a text is typed, shown above the keyboard so it is never
/// covered; the sheet shows the text live (F-07).
class TextEditPanel extends StatefulWidget {
  const TextEditPanel({
    super.key,
    required this.initialText,
    required this.hint,
    required this.doneLabel,
    required this.onChanged,
    required this.onDone,
  });

  final String initialText;
  final String hint;
  final String doneLabel;
  final ValueChanged<String> onChanged;
  final VoidCallback onDone;

  @override
  State<TextEditPanel> createState() => _TextEditPanelState();
}

class _TextEditPanelState extends State<TextEditPanel> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tokens.paper,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                minLines: 1,
                maxLines: 3,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.sentences,
                // Incognito keyboard: nothing the child writes is learned or
                // stored by the keyboard (ADR 0013).
                enableIMEPersonalizedLearning: false,
                style: const TextStyle(fontSize: 24, color: Tokens.ink),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  filled: true,
                  fillColor: Tokens.sheet,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Tokens.border),
                  ),
                ),
                onChanged: widget.onChanged,
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: widget.doneLabel,
              onPressed: widget.onDone,
              iconSize: 32,
              constraints: const BoxConstraints.tightFor(
                width: Tokens.minTouchTarget + 8,
                height: Tokens.minTouchTarget + 8,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Tokens.mint,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
