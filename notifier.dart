import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class Notifier {
  static final _p = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    await _p.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
  }

  static Future<bool> requestPermission() async {
    final a = _p.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await a?.requestNotificationsPermission() ?? true;
  }

  static Future<void> cancelAll() => _p.cancelAll();

  static Future<void> schedule(
      int id, tz.TZDateTime when, String title, String body) {
    return _p.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'lessons',
          'Напоминания о парах',
          channelDescription: 'Уведомление перед началом пары',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
