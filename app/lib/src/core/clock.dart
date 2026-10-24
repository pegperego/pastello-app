import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time. Replaced in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
