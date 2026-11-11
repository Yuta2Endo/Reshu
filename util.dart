import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const weekdayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const weekdayFull = [
  'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'
];
const monthShort = [
  'янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
];

/// Пары идут по красноярскому времени, поэтому всё считаем в нём.
void initTimezone() {
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Krasnoyarsk'));
}

tz.TZDateTime campusNow() => tz.TZDateTime.now(tz.local);
tz.TZDateTime campusTime(int y, int m, int d, [int h = 0, int min = 0]) =>
    tz.TZDateTime(tz.local, y, m, d, h, min);

int isoWeek(DateTime d) {
  final date = DateTime.utc(d.year, d.month, d.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final yearStart = DateTime.utc(thursday.year, 1, 1);
  return thursday.difference(yearStart).inDays ~/ 7 + 1;
}

/// 1 или 2. Если на сайте чётность наоборот — включается «инвертировать».
int weekParity(DateTime d, {bool invert = false}) {
  final w = isoWeek(d).isEven ? 2 : 1;
  return invert ? (w == 1 ? 2 : 1) : w;
}

String two(int v) => v.toString().padLeft(2, '0');

String relativeDay(DateTime date, DateTime now) {
  final a = DateTime(date.year, date.month, date.day);
  final b = DateTime(now.year, now.month, now.day);
  final diff = a.difference(b).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Завтра';
  return '${weekdayShort[date.weekday - 1]}, ${date.day} ${monthShort[date.month - 1]}';
}
