import 'dart:io';

/// Writes [contents] to [file] so that an interruption (crash, dead battery)
/// never leaves a half-written file: the data goes to a temporary file that
/// is then renamed over the target (ADR 0010).
Future<void> writeFileAtomically(File file, String contents) async {
  await file.parent.create(recursive: true);
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsString(contents, flush: true);
  await temporary.rename(file.path);
}
