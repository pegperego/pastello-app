import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
