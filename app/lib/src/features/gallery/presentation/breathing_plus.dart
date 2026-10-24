import 'package:flutter/material.dart';

import '../../../app/tokens.dart';

/// The big "+" that creates a new drawing.
///
/// It slowly "breathes" to invite the child to tap it (F-15), unless the
/// system asks to remove animations (G-08).
class BreathingPlus extends StatefulWidget {
  const BreathingPlus({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
  });

  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  State<BreathingPlus> createState() => _BreathingPlusState();
}

class _BreathingPlusState extends State<BreathingPlus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(
      begin: 1,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: ScaleTransition(
        scale: scale,
        child: Material(
          color: Tokens.coral,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onPressed,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: const Border(
                  bottom: BorderSide(color: Tokens.coralDark, width: 4),
                ),
              ),
              child: const Center(
                child: Icon(Icons.add_rounded, color: Colors.white, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
