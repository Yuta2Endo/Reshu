import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifier.dart';
import 'sources.dart';
import 'util.dart';

typedef NextLesson = ({Lesson lesson, DateTime date});

class AppState extends ChangeNotifier {
  AppState._(this.prefs);
  final SharedPreferences prefs;
  final _remote = PalladaSource();
  final _demo = DemoSource();

  List<GroupRef> favorites = [];
  GroupRef? active;
  List<Lesson> lessons = [];
  DateTime? updatedAt;
  bool loading = false;
  String? error;

  List<NewsItem> news = [];
  bool newsLoading = false;
  String? newsError;

  ThemeMode themeMode = ThemeMode.system;
  int seed = 0xFF3F51B5;
  bool notify = false;
  int notifyMin = 15;
  bool invertWeek = false;

  static Future<AppState> load() async {
    final s = AppState._(await SharedPreferences.getInstance());
    final p = s.prefs;
    s.favorites = (p.getStringList('favorites') ?? [])
        .map((e) => GroupRef.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
    final a = p.getString('active');
    if (a != null) {
      s.active = GroupRef.fromJson(jsonDecode(a) as Map<String, dynamic>);
      s._loadCache();
    }
    s.themeMode = ThemeMode.values[p.getInt('theme') ?? 0];
    s.seed = p.getInt('seed') ?? s.seed;
    s.notify = p.getBool('notify') ?? false;
    s.notifyMin = p.getInt('notifyMin') ?? 15;
    s.invertWeek = p.getBool('invertWeek') ?? false;
    final n = p.getString('news_cache');
    if (n != null) {
      s.news = (jsonDecode(n) as List)
          .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return s;
  }

  TimetableSource _src(GroupRef g) => g.id == DemoSource.group.id ? _demo : _remote;

  void _loadCache() {
    final g = active;
    if (g == null) return;
    final raw = prefs.getString('cache_${g.id}');
    lessons = raw == null
        ? []
        : (jsonDecode(raw) as List)
            .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
            .toList();
    final t = prefs.getInt('cache_time_${g.id}');
    updatedAt = t == null ? null : DateTime.fromMillisecondsSinceEpoch(t);
  }

  Future<List<GroupRef>> searchGroups(String q) => _remote.search(q);

  Future<void> selectGroup(GroupRef g) async {
    active = g;
    if (!favorites.contains(g)) favorites = [...favorites, g];
    error = null;
    await prefs.setString('active', jsonEncode(g.toJson()));
    await _saveFavorites();
    _loadCache();
    notifyListeners();
    refreshTimetable();
  }

  Future<void> removeFavorite(GroupRef g) async {
    favorites = favorites.where((e) => e != g).toList();
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> _saveFavorites() => prefs.setStringList(
      'favorites', favorites.map((e) => jsonEncode(e.toJson())).toList());

  Future<void> refreshTimetable() async {
    final g = active;
    if (g == null || loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final l = await _src(g).load(g);
      lessons = l;
      updatedAt = DateTime.now();
      await prefs.setString('cache_${g.id}', jsonEncode(l.map((e) => e.toJson()).toList()));
      await prefs.setInt('cache_time_${g.id}', updatedAt!.millisecondsSinceEpoch);
      await _reschedule();
    } catch (e) {
      error = lessons.isEmpty
          ? 'Не удалось загрузить расписание: $e'
          : 'Не удалось обновить ($e). Показано сохранённое расписание.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> refreshNews() async {
    if (newsLoading) return;
    newsLoading = true;
    newsError = null;
    notifyListeners();
    try {
      news = await fetchNews();
      await prefs.setString('news_cache', jsonEncode(news.map((e) => e.toJson()).toList()));
    } catch (e) {
      newsError = news.isEmpty
          ? 'Не удалось загрузить новости: $e'
          : 'Нет связи. Показаны сохранённые новости.';
    }
    newsLoading = false;
    notifyListeners();
  }

  List<Lesson> lessonsFor(int weekday, int week) {
    final l = lessons
        .where((e) => e.weekday == weekday && (e.week == 0 || e.week == week))
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return l;
  }

  NextLesson? nextLesson() {
    final now = campusNow();
    final nowMin = now.hour * 60 + now.minute;
    for (var off = 0; off < 14; off++) {
      final d = campusTime(now.year, now.month, now.day).add(Duration(days: off));
      for (final l in lessonsFor(d.weekday, weekParity(d, invert: invertWeek))) {
        if (off == 0 && l.startMinutes <= nowMin) continue;
        return (lesson: l, date: d);
      }
    }
    return null;
  }

  Future<void> _reschedule() async {
    await Notifier.cancelAll();
    if (!notify) return;
    final now = campusNow();
    var id = 1;
    for (var off = 0; off < 14; off++) {
      final d = campusTime(now.year, now.month, now.day).add(Duration(days: off));
      for (final l in lessonsFor(d.weekday, weekParity(d, invert: invertWeek))) {
        final p = l.start.split(':');
        final when = campusTime(d.year, d.month, d.day, int.parse(p[0]), int.parse(p[1]))
            .subtract(Duration(minutes: notifyMin));
        if (when.isAfter(now)) {
          final extra = [l.type, if (l.room.isNotEmpty) 'ауд. ${l.room}']
              .where((e) => e.isNotEmpty)
              .join(' · ');
          await Notifier.schedule(
              id++, when, '${l.start} — ${l.title}', extra.isEmpty ? 'Скоро пара' : extra);
        }
      }
    }
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    await prefs.setInt('theme', m.index);
    notifyListeners();
  }

  Future<void> setSeed(int c) async {
    seed = c;
    await prefs.setInt('seed', c);
    notifyListeners();
  }

  Future<void> setNotify(bool v) async {
    if (v && !await Notifier.requestPermission()) v = false;
    notify = v;
    await prefs.setBool('notify', v);
    await _reschedule();
    notifyListeners();
  }

  Future<void> setNotifyMin(int m) async {
    notifyMin = m;
    await prefs.setInt('notifyMin', m);
    await _reschedule();
    notifyListeners();
  }

  Future<void> setInvertWeek(bool v) async {
    invertWeek = v;
    await prefs.setBool('invertWeek', v);
    await _reschedule();
    notifyListeners();
  }
}
