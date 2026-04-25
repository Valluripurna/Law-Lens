import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
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

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  static Future<void> requestPermissions() async {
    try {
        await _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch(e) {
        debugPrint("Error requesting notification permissions: $e");
    }
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
      id: 0,
      title: 'Live Map Tracker 🗺️',
      body: 'You have moved 1km into a new area. Stay alert for checkposts!',
      notificationDetails: notificationDetails,
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
      id: 1,
      title: 'Law Lens AI is Ready ⚖️',
      body: 'Have any traffic or legal questions today? Check them now.',
      repeatInterval: RepeatInterval.daily,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
