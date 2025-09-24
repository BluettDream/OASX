import 'package:get/get.dart';
import 'package:oasx/translation/i18n_content.dart';

class TimeUtils {
  static String formatRelativeTime(DateTime time, DateTime now) {
    final diff = now.difference(time);

    if (diff.inSeconds <= 1) {
      return I18n.now.tr;
    } else if (diff.inSeconds <= 60) {
      return '${diff.inSeconds} ${I18n.seconds_ago.tr}';
    } else if (diff.inMinutes <= 60) {
      return "${diff.inMinutes} ${I18n.minutes_ago.tr}";
    } else if (diff.inHours <= 12) {
      return "${diff.inHours} ${I18n.hours_ago.tr}";
    } else {
      return "${diff.inDays} ${I18n.days_ago.tr}";
    }
  }
}
