import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/core/licenses.dart';

void main() {
  registerBundledLicenses();
  runApp(const ProviderScope(child: PastelloApp()));
}
