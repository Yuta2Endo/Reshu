import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'models.dart';

const kBase = 'https://timetable.pallada.sibsau.ru';
const kNewsUrl = 'https://www.sibsau.ru/newsitems/58/';
const _headers = {'User-Agent': 'Mozilla/5.0 (SibsauPlanner)'};

String _abs(String u, [String base = kBase]) =>
    u.startsWith('http') ? u : '$base${u.startsWith('/') ? '' : '/'}$u';

abstract class TimetableSource {
  Future<List<GroupRef>> search(String query);
  Future<List<Lesson>> load(GroupRef group);
}

/// ВАЖНО: адреса и разбор страницы написаны без доступа к живому сайту.
/// Если расписание не грузится — правьте только этот класс и parseTimetable().
class PalladaSource implements TimetableSource {
  final http.Client _c = http.Client();

  @override
  Future<List<GroupRef>> search(String query) async {
    final r = await _c
        .post(Uri.parse('$kBase/ajax/search_schedule'),
            headers: _headers, body: {'query': query})
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) throw Exception('сервер ответил ${r.statusCode}');
    final body = utf8.decode(r.bodyBytes);
    final out = <GroupRef>[];
    try {
      final j = jsonDecode(body);
      final list = j is List
          ? j
          : (j is Map && j['results'] is List ? j['results'] as List : const []);
      for (final e in list) {
        if (e is Map) {
          final id = '${e['id']}';
          final name = '${e['name'] ?? e['title'] ?? id}';
          out.add(GroupRef(id, name, _abs('${e['url'] ?? '/timetable/group/$id'}')));
        }
      }
    } on FormatException {
      for (final a in html.parse(body).querySelectorAll('a')) {
        final href = a.attributes['href'] ?? '';
        final name = a.text.trim();
        if (href.contains('/timetable/') && name.isNotEmpty) {
          out.add(GroupRef(href, name, _abs(href)));
        }
      }
    }
    return out;
  }

  @override
  Future<List<Lesson>> load(GroupRef group) async {
    final r = await _c
        .get(Uri.parse(group.url), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('сервер ответил ${r.statusCode}');
    final lessons = parseTimetable(utf8.decode(r.bodyBytes));
    if (lessons.isEmpty) {
      throw const FormatException('не удалось разобрать страницу расписания');
    }
    return lessons;
  }
}

class _Draft {
  final String start, end;
  final int week;
  String title = '', type = '', room = '', teacher = '';
  _Draft(this.start, this.end, this.week);
}

/// Разбор «по токенам»: обходим текст страницы и собираем пары по шаблону
/// «день недели → время → название / тип / аудитория / преподаватель».
List<Lesson> parseTimetable(String htmlText) {
  final root = html.parse(htmlText).body;
  if (root == null) return [];
  final tokens = <String>[];
  void walk(dom.Node n) {
    if (n is dom.Text) {
      final t = n.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (t.isNotEmpty) tokens.add(t);
    } else if (n is dom.Element) {
      if (n.localName == 'script' || n.localName == 'style') return;
      n.nodes.forEach(walk);
    }
  }

  walk(root);

  const days = {
    'понедельник': 1, 'вторник': 2, 'среда': 3, 'четверг': 4,
    'пятница': 5, 'суббота': 6, 'воскресенье': 7,
  };
  final timeRe = RegExp(r'(\d{1,2}:\d{2})\s*[–—-]\s*(\d{1,2}:\d{2})');
  final teacherRe =
      RegExp(r'^[А-ЯЁ][а-яё]+(?:-[А-ЯЁ][а-яё]+)? [А-ЯЁ]\.\s?(?:[А-ЯЁ]\.)?$');
  final typeRe = RegExp(
      r'^(лекция|практика|практическое|лабораторная|семинар|консультация|экзамен|зачет|зачёт)');
  final roomOnly = RegExp(r'^\d{1,3}(?:[-–]\d{1,3})?[А-Яа-я]?$');
  final weekRe = RegExp(r'(?:^(\d)\s*(?:-?я)?\s*неделя)|(?:неделя\s*(\d))');

  final out = <Lesson>[];
  var day = 0, week = 0;
  _Draft? cur;

  void flush() {
    final c = cur;
    if (c != null && c.title.isNotEmpty && day != 0) {
      out.add(Lesson(
        weekday: day, week: c.week, start: c.start, end: c.end,
        title: c.title, type: c.type, room: c.room, teacher: c.teacher,
      ));
    }
    cur = null;
  }

  for (final t in tokens) {
    final tl = t.toLowerCase();
    if (t.length <= 30) {
      final wd = days.entries.where((e) => tl.startsWith(e.key)).firstOrNull;
      if (wd != null) {
        flush();
        day = wd.value;
        continue;
      }
    }
    final wk = weekRe.firstMatch(tl);
    if (wk != null && t.length <= 14) {
      flush();
      final w = int.parse(wk.group(1) ?? wk.group(2)!);
      week = (w == 1 || w == 2) ? w : 0;
      continue;
    }
    final tm = timeRe.firstMatch(t);
    if (tm != null) {
      flush();
      cur = _Draft(tm.group(1)!, tm.group(2)!, week);
      continue;
    }
    final c = cur;
    if (c == null) continue;
    if (typeRe.hasMatch(tl)) {
      c.type = t;
    } else if (teacherRe.hasMatch(t)) {
      c.teacher = c.teacher.isEmpty ? t : '${c.teacher}, $t';
    } else if (tl.startsWith('ауд') || tl.startsWith('каб') || roomOnly.hasMatch(t)) {
      c.room = t;
    } else if (c.title.isEmpty) {
      c.title = t;
    }
  }
  flush();
  return out;
}

/// Встроенное демо-расписание: приложение можно проверить без сайта.
class DemoSource implements TimetableSource {
  static const group = GroupRef('demo', 'Демо-группа', 'demo');

  @override
  Future<List<GroupRef>> search(String query) async => [group];

  @override
  Future<List<Lesson>> load(GroupRef g) async {
    Lesson l(int d, int w, String s, String e, String t, String ty, String r, String p) =>
        Lesson(weekday: d, week: w, start: s, end: e, title: t, type: ty, room: r, teacher: p);
    return [
      l(1, 0, '08:30', '10:05', 'Математический анализ', 'Лекция', 'А-101', 'Иванов И. И.'),
      l(1, 0, '10:15', '11:50', 'Программирование', 'Лабораторная', 'Б-204', 'Петрова А. С.'),
      l(1, 1, '12:10', '13:45', 'Физика', 'Практика', 'А-305', 'Сидоров П. П.'),
      l(2, 0, '10:15', '11:50', 'Базы данных', 'Лекция', 'Б-110', 'Кузнецова Е. В.'),
      l(2, 2, '12:10', '13:45', 'Английский язык', 'Практика', 'В-12', 'Смирнова О. Н.'),
      l(3, 0, '08:30', '10:05', 'Алгоритмы', 'Лекция', 'А-101', 'Орлов Д. А.'),
      l(3, 0, '10:15', '11:50', 'Алгоритмы', 'Практика', 'Б-204', 'Орлов Д. А.'),
      l(4, 1, '10:15', '11:50', 'Дискретная математика', 'Лекция', 'А-210', 'Волков С. М.'),
      l(4, 2, '10:15', '11:50', 'Философия', 'Лекция', 'В-01', 'Попова Н. Л.'),
      l(5, 0, '12:10', '13:45', 'Физическая культура', 'Практика', 'Спортзал', 'Морозов К. К.'),
      l(5, 0, '14:00', '15:35', 'Проектная работа', 'Семинар', 'Б-301', 'Белова Т. Р.'),
    ];
  }
}

Future<List<NewsItem>> fetchNews() async {
  final r = await http
      .get(Uri.parse(kNewsUrl), headers: _headers)
      .timeout(const Duration(seconds: 15));
  if (r.statusCode != 200) throw Exception('сервер ответил ${r.statusCode}');
  final seen = <String>{};
  final out = <NewsItem>[];
  final re = RegExp(r'/newsitem[s]?/\d+');
  for (final a in html.parse(utf8.decode(r.bodyBytes)).querySelectorAll('a')) {
    final href = a.attributes['href'] ?? '';
    final text = a.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (!re.hasMatch(href) || text.length < 15) continue;
    final url = _abs(href, 'https://www.sibsau.ru');
    if (seen.add(url)) out.add(NewsItem(text, url));
  }
  if (out.isEmpty) throw const FormatException('новости не найдены на странице');
  return out;
}
