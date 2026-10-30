import 'dart:io';

import 'package:flutter/services.dart';

/// The Android system file pickers (ADR 0020): the parent chooses where a
/// file is saved or which file is opened.
abstract interface class DocumentPicker {
  /// Lets the user choose where to save a copy of [file], suggesting
  /// [name]. Returns `false` if the user cancels.
  Future<bool> save(File file, {required String name});

  /// Lets the user choose a file and copies it to [target]. Returns `false`
  /// if the user cancels.
  Future<bool> open(File target);
}

/// [DocumentPicker] backed by `MainActivity`.
class PlatformDocumentPicker implements DocumentPicker {
  const PlatformDocumentPicker();

  static const _channel = MethodChannel(
    'io.github.pegperego.pastello/documents',
  );

  @override
  Future<bool> save(File file, {required String name}) async =>
      await _channel.invokeMethod<bool>('save', {
        'path': file.path,
        'name': name,
      }) ??
      false;

  @override
  Future<bool> open(File target) async =>
      await _channel.invokeMethod<bool>('open', {'path': target.path}) ?? false;
}
