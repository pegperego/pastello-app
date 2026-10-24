import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pastello/src/app/app_icon.dart';

void main() {
  test('every action icon and the mascot have their drawing', () {
    for (final icon in AppIcons.values) {
      expect(File(icon.asset).existsSync(), isTrue, reason: icon.asset);
    }
    expect(File('assets/mascot.svg').existsSync(), isTrue);
  });
}
