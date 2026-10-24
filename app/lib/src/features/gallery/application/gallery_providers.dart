import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/drawing_summary.dart';

/// The drawings shown in the gallery, newest first.
///
/// Empty until storage is implemented (issue #5); tests override it.
final drawingsProvider = Provider<List<DrawingSummary>>((ref) => const []);
