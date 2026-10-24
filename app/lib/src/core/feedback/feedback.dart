import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import '../settings/settings_providers.dart';

/// The short sounds of the app (F-15). Never while drawing.
enum AppSound {
  /// A sticker lands on the sheet.
  pop,

  /// Something goes to the trash.
  whoosh,

  /// A drawing was saved to the gallery or sent to the printer.
  ding;

  String get asset => 'sounds/$name.wav';
}

/// Plays sounds and light vibrations, if the grown-ups left them on in the
/// parents' page.
class Feedback {
  Feedback(this._settings, this._play);

  final AppSettings Function() _settings;
  final Future<void> Function(AppSound sound) _play;

  /// Plays [sound] when sounds are on.
  Future<void> sound(AppSound sound) async {
    if (_settings().sounds) await _play(sound);
  }

  /// A light tick: a shape snapping, a tool changing (F-12, F-15).
  Future<void> tick() async {
    if (_settings().haptics) await HapticFeedback.selectionClick();
  }
}

/// Plays a sound asset. Replaced in tests.
final soundPlayerProvider = Provider<Future<void> Function(AppSound)>((ref) {
  final players = <AppSound, AudioPlayer>{};
  ref.onDispose(() {
    for (final player in players.values) {
      player.dispose();
    }
  });
  return (sound) async {
    final player = players.putIfAbsent(
      sound,
      () => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency),
    );
    await player.stop();
    await player.play(AssetSource(sound.asset), volume: 0.6);
  };
});

/// Sounds and vibrations.
final feedbackProvider = Provider<Feedback>(
  (ref) => Feedback(
    () => ref.read(settingsProvider).value ?? const AppSettings(),
    ref.watch(soundPlayerProvider),
  ),
);
