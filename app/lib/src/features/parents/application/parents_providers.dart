import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The project's public pages (ADR 0017: the only external links, shown in
/// the parents' page only).
abstract final class ProjectLinks {
  static final source = Uri.parse('https://github.com/pegperego/pastello-app');
  static final issues = Uri.parse(
    'https://github.com/pegperego/pastello-app/issues/new/choose',
  );
  static final privacy = Uri.parse(
    'https://pegperego.github.io/pastello-app/privacy-policy.html',
  );
}

/// What a bug report needs to know (ADR 0003). Nothing is sent anywhere:
/// a grown-up copies it into an issue.
@immutable
class AppInfo {
  const AppInfo({
    required this.version,
    required this.device,
    required this.android,
  });

  final String version;
  final String device;
  final String android;

  /// The text copied for a bug report.
  String get report => 'Pastello $version\nDevice: $device\nAndroid: $android';
}

/// Version and device, read from the system. Replaced in tests.
final appInfoProvider = FutureProvider<AppInfo>((ref) async {
  final package = await PackageInfo.fromPlatform();
  final android = await DeviceInfoPlugin().androidInfo;
  return AppInfo(
    version: '${package.version} (${package.buildNumber})',
    device: '${android.manufacturer} ${android.model}',
    android: android.version.release,
  );
});

/// Opens a link in the browser, outside the app. Replaced in tests.
final linkOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
