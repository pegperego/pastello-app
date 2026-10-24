import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';

/// "today", "yesterday" or a short date such as "12 ott" (F-09).
String relativeDate(
  AppLocalizations l10n,
  String locale,
  DateTime date,
  DateTime now,
) {
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days == 0) return l10n.today;
  if (days == 1) return l10n.yesterday;
  return date.year == now.year
      ? DateFormat.MMMd(locale).format(date)
      : DateFormat.yMMMd(locale).format(date);
}
