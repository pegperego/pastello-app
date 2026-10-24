import 'package:flutter/foundation.dart';

/// Orientation kept by the rotation lock (ADR 0002).
enum LockedOrientation { landscape, portrait }

/// Preferences remembered between sessions.
///
/// Stored by name and value rather than by enum index, so that reordering
/// enums in a future version never mixes up saved settings.
@immutable
class AppSettings {
  const AppSettings({
    this.tool,
    this.color,
    this.extraColor,
    this.widths = const {},
    this.leftHanded = false,
    this.rotationLock,
  });

  /// Restores settings from JSON, ignoring anything unknown or malformed.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    final widths = json['widths'];
    final lock = json['rotationLock'];
    return AppSettings(
      tool: json['tool'] is String ? json['tool'] as String : null,
      color: json['color'] is int ? json['color'] as int : null,
      extraColor: json['extraColor'] is int ? json['extraColor'] as int : null,
      widths: widths is Map
          ? {
              for (final MapEntry(:key, :value) in widths.entries)
                if (key is String && value is String) key: value,
            }
          : const {},
      leftHanded: json['leftHanded'] == true,
      rotationLock: LockedOrientation.values
          .where((o) => o.name == lock)
          .firstOrNull,
    );
  }

  /// Name of the selected tool.
  final String? tool;

  /// Selected drawing color, as ARGB.
  final int? color;

  /// Last color picked from the "more colors" grid, as ARGB (F-05).
  final int? extraColor;

  /// Width preset name for each tool name (F-06).
  final Map<String, String> widths;

  /// Swaps the tool and color columns (F-03).
  final bool leftHanded;

  /// Orientation locked by the user, or `null` to follow the device.
  final LockedOrientation? rotationLock;

  /// Returns a copy with the given fields replaced.
  ///
  /// [rotationLock] uses a function so that it can be set back to `null`.
  AppSettings copyWith({
    String? tool,
    int? color,
    int? extraColor,
    Map<String, String>? widths,
    bool? leftHanded,
    LockedOrientation? Function()? rotationLock,
  }) => AppSettings(
    tool: tool ?? this.tool,
    color: color ?? this.color,
    extraColor: extraColor ?? this.extraColor,
    widths: widths ?? this.widths,
    leftHanded: leftHanded ?? this.leftHanded,
    rotationLock: rotationLock != null ? rotationLock() : this.rotationLock,
  );

  /// JSON representation, see [AppSettings.fromJson].
  Map<String, Object?> toJson() => {
    'tool': ?tool,
    'color': ?color,
    'extraColor': ?extraColor,
    'widths': widths,
    'leftHanded': leftHanded,
    'rotationLock': ?rotationLock?.name,
  };
}
