import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:pastello/src/app/app.dart';
import 'package:pastello/src/core/settings/app_settings.dart';
import 'package:pastello/src/core/settings/settings_providers.dart';
import 'package:pastello/src/core/clock.dart';
import 'package:pastello/src/core/settings/settings_repository.dart';
import 'package:pastello/src/features/drawings/application/drawings_providers.dart';
import 'package:pastello/src/features/drawings/data/drawing_repository.dart';
import 'package:pastello/src/features/drawings/domain/drawing_summary.dart';
import 'package:pastello/src/features/drawings/domain/saved_drawing.dart';
import 'package:pastello/src/features/parents/application/parents_providers.dart';
import 'package:pastello/src/features/stickers/application/stickers_providers.dart';
import 'package:pastello/src/features/stickers/data/bundled_packs.dart';
import 'package:pastello/src/features/stickers/domain/sticker_pack.dart';
import 'package:pastello_engine/pastello_engine.dart';

/// Settings kept in memory, for tests.
class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository([this.saved = const AppSettings()]);

  AppSettings saved;

  @override
  Future<AppSettings> load() async => saved;

  @override
  Future<void> save(AppSettings settings) async => saved = settings;
}

/// A 1×1 transparent PNG, used as thumbnail in widget tests.
final transparentPng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

/// Fixed "now" for widget tests: Saturday 24 October 2026, 18:00.
final testNow = DateTime(2026, 10, 24, 18);

/// Drawings kept in memory, for widget tests. The file implementation is
/// tested separately with a real directory.
class MemoryDrawingRepository implements DrawingRepository {
  final Map<String, (SavedDrawing, DrawingSummary)> drawings = {};
  final Map<String, (SavedDrawing, DrawingSummary)> trash = {};
  int saves = 0;

  /// Adds a drawing with one stroke, last changed at [updatedAt].
  void add(String id, DateTime updatedAt) {
    final drawing = const Drawing(sheetSize: Size(400, 300)).withElementAdded(
      StrokeElement(
        id: newElementId(),
        tool: StrokeTool.marker,
        color: const Color(0xFF1D4ED8),
        width: 10,
        points: const [SheetPoint(10, 10), SheetPoint(200, 150)],
      ),
    );
    drawings[id] = (
      SavedDrawing(drawing: drawing),
      DrawingSummary(id: id, updatedAt: updatedAt, thumbnail: transparentPng),
    );
  }

  List<DrawingSummary> _sorted(Iterable<(SavedDrawing, DrawingSummary)> all) =>
      [for (final (_, s) in all) s]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<List<DrawingSummary>> list() async => _sorted(drawings.values);

  @override
  Future<List<DrawingSummary>> listTrash() async => _sorted(trash.values);

  @override
  Future<SavedDrawing?> load(String id) async => drawings[id]?.$1;

  @override
  Future<void> save(
    String id,
    Drawing drawing, {
    List<DrawingCommand> undo = const [],
    List<DrawingCommand> redo = const [],
    Uint8List? thumbnail,
  }) async {
    saves++;
    drawings[id] = (
      SavedDrawing(drawing: drawing, undo: undo, redo: redo),
      DrawingSummary(id: id, updatedAt: testNow, thumbnail: thumbnail),
    );
  }

  @override
  Future<String> duplicate(String id) async {
    final copy = '$id-copy';
    final (saved, summary) = drawings[id]!;
    drawings[copy] = (
      SavedDrawing(drawing: saved.drawing),
      DrawingSummary(
        id: copy,
        updatedAt: testNow,
        thumbnail: summary.thumbnail,
      ),
    );
    return copy;
  }

  @override
  Future<void> moveToTrash(String id) async {
    final entry = drawings.remove(id);
    if (entry != null) trash[id] = entry;
  }

  @override
  Future<void> restore(String id) async {
    final entry = trash.remove(id);
    if (entry != null) drawings[id] = entry;
  }

  @override
  Future<void> emptyTrash() async => trash.clear();

  @override
  Future<int> purgeTrash() async => 0;
}

/// The bundled sticker packs, loaded once per test file by [loadTestPacks].
///
/// Reading assets needs real asynchronous work, which widget tests' fake
/// time does not provide; loading them up front keeps the tests fast and
/// deterministic.
List<StickerPack> testPacks = const [];

/// Loads [testPacks]; call it from `setUpAll`.
Future<void> loadTestPacks() async {
  testPacks = await loadBundledPacks(rootBundle);
}

/// Records the orientations requested by the rotation lock.
final requestedOrientations = <List<DeviceOrientation>>[];

/// Records the links opened from the parents' page.
final openedLinks = <Uri>[];

/// Overrides every provider that touches the platform.
List<Override> testOverrides(
  MemorySettingsRepository settings, [
  MemoryDrawingRepository? drawings,
]) => [
  settingsRepositoryProvider.overrideWithValue(settings),
  drawingRepositoryProvider.overrideWithValue(
    drawings ?? MemoryDrawingRepository(),
  ),
  thumbnailRendererProvider.overrideWithValue((_) async => transparentPng),
  clockProvider.overrideWithValue(() => testNow),
  stickerPacksProvider.overrideWith((ref) async => testPacks),
  appInfoProvider.overrideWith(
    (ref) async => const AppInfo(
      version: '0.1.0 (1)',
      device: 'Xiaomi 2505DRP06E',
      android: '16',
    ),
  ),
  linkOpenerProvider.overrideWithValue((uri) async {
    openedLinks.add(uri);
    return true;
  }),
  // Stickers render as placeholders: no SVG work in widget tests.
  stickerArtworkProvider.overrideWith((ref) async => PackArtwork(const {})),
  orientationSetterProvider.overrideWithValue((orientations) async {
    requestedOrientations.add(orientations);
  }),
];

/// Pumps the whole app in [locale], with optional provider [overrides].
Future<void> pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('it'),
  List<Override> overrides = const [],
  MemorySettingsRepository? settings,
  MemoryDrawingRepository? drawings,
  bool disableAnimations = false,
}) async {
  requestedOrientations.clear();
  openedLinks.clear();
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.accessibilityFeaturesTestValue = disableAnimations
      ? const FakeAccessibilityFeatures(disableAnimations: true)
      : const FakeAccessibilityFeatures();
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  // Start from an empty tree, so a second call does not keep the previous
  // app's navigation stack.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...testOverrides(settings ?? MemorySettingsRepository(), drawings),
        ...overrides,
      ],
      child: const PastelloApp(),
    ),
  );
  await tester.pump();
}

/// Pumps a second of frames: enough for page transitions to finish.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
