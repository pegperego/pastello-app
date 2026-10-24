import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/core/settings/app_settings.dart';
import 'package:pastello/src/core/settings/settings_providers.dart';
import 'package:pastello/src/core/settings/settings_repository.dart';
import 'package:flutter/services.dart';

void main() {
  const full = AppSettings(
    tool: 'brush',
    color: 0xFFE63946,
    extraColor: 0xFF00C2A8,
    widths: {'brush': 'extraThick'},
    leftHanded: true,
    rotationLock: LockedOrientation.portrait,
  );

  group('AppSettings', () {
    test('round-trips through JSON', () {
      final restored = AppSettings.fromJson(full.toJson());
      expect(restored.toJson(), full.toJson());
    });

    test('ignores unknown and malformed values', () {
      final restored = AppSettings.fromJson({
        'tool': 42,
        'color': 'red',
        'widths': {'brush': 3, 'pencil': 'thin'},
        'leftHanded': 'yes',
        'rotationLock': 'sideways',
        'unknown': true,
      });
      expect(restored.tool, isNull);
      expect(restored.color, isNull);
      expect(restored.widths, {'pencil': 'thin'});
      expect(restored.leftHanded, isFalse);
      expect(restored.rotationLock, isNull);
    });

    test('copyWith can clear the rotation lock', () {
      expect(full.copyWith(rotationLock: () => null).rotationLock, isNull);
      expect(full.copyWith(tool: 'pencil').rotationLock, isNotNull);
    });
  });

  group('FileSettingsRepository', () {
    late Directory directory;
    setUp(() => directory = Directory.systemTemp.createTempSync('pastello'));
    tearDown(() => directory.deleteSync(recursive: true));

    test('returns defaults on first launch', () async {
      final settings = await FileSettingsRepository(directory).load();
      expect(settings.toJson(), const AppSettings().toJson());
    });

    test('saves atomically and loads back', () async {
      final repository = FileSettingsRepository(directory);
      await repository.save(full);
      expect((await repository.load()).toJson(), full.toJson());
      expect(directory.listSync().map((f) => f.uri.pathSegments.last), [
        'settings.json',
      ]);
    });

    test('survives a corrupted file', () async {
      File('${directory.path}/settings.json').writeAsStringSync('{oops');
      final settings = await FileSettingsRepository(directory).load();
      expect(settings.leftHanded, isFalse);
    });
  });

  test('orientation locks map to system orientations', () {
    expect(orientationsFor(null), isEmpty);
    expect(
      orientationsFor(LockedOrientation.landscape),
      contains(DeviceOrientation.landscapeLeft),
    );
    expect(
      orientationsFor(LockedOrientation.portrait),
      contains(DeviceOrientation.portraitUp),
    );
  });
}
