class GroupRef {
  final String id, name, url;
  const GroupRef(this.id, this.name, this.url);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url};
  factory GroupRef.fromJson(Map<String, dynamic> j) =>
      GroupRef(j['id'] as String, j['name'] as String, j['url'] as String);

  @override
  bool operator ==(Object other) => other is GroupRef && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class Lesson {
  final int weekday; // 1 = понедельник
  final int week; // 0 = каждую неделю, 1 или 2
  final String start, end, title, type, room, teacher;

  const Lesson({
    required this.weekday,
    required this.week,
    required this.start,
    required this.end,
    required this.title,
    this.type = '',
    this.room = '',
    this.teacher = '',
  });

  static int _min(String t) {
    final p = t.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  int get startMinutes => _min(start);
  int get endMinutes => _min(end);

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'week': week,
        'start': start,
        'end': end,
        'title': title,
        'type': type,
        'room': room,
        'teacher': teacher,
      };

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        weekday: j['weekday'] as int,
        week: j['week'] as int,
        start: j['start'] as String,
        end: j['end'] as String,
        title: j['title'] as String,
        type: (j['type'] ?? '') as String,
        room: (j['room'] ?? '') as String,
        teacher: (j['teacher'] ?? '') as String,
      );
}

class NewsItem {
  final String title, url;
  const NewsItem(this.title, this.url);
  Map<String, dynamic> toJson() => {'title': title, 'url': url};
  factory NewsItem.fromJson(Map<String, dynamic> j) =>
      NewsItem(j['title'] as String, j['url'] as String);
}
