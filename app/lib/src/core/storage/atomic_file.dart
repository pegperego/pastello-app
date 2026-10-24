import 'dart:convert';
import 'dart:io';

/// Writes [contents] (UTF-8) to [file] so that an interruption (crash, dead
/// battery) never leaves a half-written file: the data goes to a temporary
/// file that is then renamed over the target (ADR 0010).
Future<void> writeFileAtomically(File file, String contents) =>
    writeBytesAtomically(file, utf8.encode(contents));

/// Like [writeFileAtomically], for binary data.
Future<void> writeBytesAtomically(File file, List<int> bytes) async {
  await file.parent.create(recursive: true);
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsBytes(bytes, flush: true);
  await temporary.rename(file.path);
}
