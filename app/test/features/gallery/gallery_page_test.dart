import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/features/editor/presentation/editor_page.dart';
import 'package:pastello/src/features/gallery/application/gallery_providers.dart';
import 'package:pastello/src/features/gallery/domain/drawing_summary.dart';
import 'package:pastello/src/features/gallery/presentation/gallery_page.dart';

import '../../helpers.dart';

void main() {
  testWidgets('an empty gallery shows only the "+"', (tester) async {
    await pumpApp(tester);
    expect(find.byType(GalleryPage), findsOneWidget);
    expect(find.text('Pastello'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('"+" opens the editor and home goes back', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Nuovo disegno'));
    await tester.pump();
    // The "+" breathes forever, so pumpAndSettle would never settle:
    // pump frames past the page transition instead.
    await pumpFrames(tester);
    expect(find.byType(EditorPage), findsOneWidget);
    expect(find.bySemanticsLabel('Foglio'), findsOneWidget);

    expect(find.byTooltip('Torna alla galleria'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.home_rounded));
    await pumpFrames(tester);
    expect(find.byType(EditorPage), findsNothing);
  });

  testWidgets('the "+" breathes, unless animations are disabled', (
    tester,
  ) async {
    await pumpApp(tester);
    final scale = find.byType(ScaleTransition).first;
    expect(tester.hasRunningAnimations, isTrue);
    expect(tester.widget<ScaleTransition>(scale), isNotNull);

    await pumpApp(tester, disableAnimations: true);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('saved drawings get a tile after the "+"', (tester) async {
    await pumpApp(
      tester,
      overrides: [
        drawingsProvider.overrideWithValue([
          DrawingSummary(id: 'a', updatedAt: DateTime(2026, 10, 24)),
        ]),
      ],
    );
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect((grid.childrenDelegate as SliverChildBuilderDelegate).childCount, 2);
  });
}
