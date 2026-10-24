import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The action icons drawn for Pastello (G-06), in `assets/icons/actions/`.
enum AppIcons {
  home,
  undo,
  redo,
  paper,
  lock,
  print,
  more,
  trash,
  parents,
  duplicate,
  delete,
  rotate;

  String get asset => 'assets/icons/actions/$name.svg';
}

/// One of [AppIcons], tinted like an [Icon]: it follows the surrounding
/// [IconTheme], so buttons can grey it out when disabled.
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size, this.color});

  final AppIcons icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final side = size ?? theme.size ?? 24;
    return SvgPicture.asset(
      icon.asset,
      width: side,
      height: side,
      colorFilter: ColorFilter.mode(
        color ?? theme.color ?? const Color(0xFF2D2A32),
        BlendMode.srcIn,
      ),
    );
  }
}

/// The smiling crayon (G-04), the face of the app.
class Mascot extends StatelessWidget {
  const Mascot({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size / 4),
    child: SvgPicture.asset('assets/mascot.svg', width: size, height: size),
  );
}
