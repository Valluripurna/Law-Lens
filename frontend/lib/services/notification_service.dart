import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidInitializationSettings = 
        // Need a valid icon from android/app/src/main/res/drawable or mipmap. We have @mipmap/launcher_icon.
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
    );

    // Request permissions for Android 13+
    await _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> showZoneAlert() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'zone_alerts_channel',
      'Zone Alerts',
      channelDescription: 'Alerts when crossing into new 1km zones.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: Colors.redAccent,
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      0,
      'Live Map Tracker 🗺️',
      'You have moved 1km into a new area. Stay alert for checkposts!',
      notificationDetails,
    );
  }

  static Future<void> scheduleDailyReminder() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Reminders',
      channelDescription: 'Daily prompt to use Law Lens.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: Color(0xFFD4AF37),
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    // Schedule to appear every day at the same time
    await _notificationsPlugin.periodicallyShow(
      1,
      'Law Lens AI is Ready ⚖️',
      'Have any traffic or legal questions today? Check them now.',
      RepeatInterval.daily,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
