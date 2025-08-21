import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:universal_html/html.dart' as html;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final StreamController<String?> _notificationStreamController =
      StreamController<String?>.broadcast();
  Stream<String?> get notificationStream =>
      _notificationStreamController.stream;

  bool _webNotificationPermissionGranted = false;

  Future<void> initialize() async {
    if (kIsWeb) {
      await _initializeWebNotifications();
      return;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _notificationStreamController.add(response.payload);
      },
    );
    await _configureLocalTimeZone();
  }

  Future<void> _initializeWebNotifications() async {
    try {
      if (html.Notification.permission == 'granted') {
        _webNotificationPermissionGranted = true;
      } else if (html.Notification.permission != 'denied') {
        final permission = await html.Notification.requestPermission();
        _webNotificationPermissionGranted = permission == 'granted';
      }
    } catch (e) {
      debugPrint('Error initializing web notifications: $e');
    }
  }

  Future<void> _configureLocalTimeZone() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();
    try {
      final location = tz.local;
      tz.setLocalLocation(location);
    } catch (e) {
      debugPrint('Error setting timezone: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<void> scheduleTaskNotification({
    required String taskId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (kIsWeb) {
      await _scheduleWebNotification(
        taskId: taskId,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
      );
      return;
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        'task_channel',
        'Task Reminders',
        channelDescription: 'Notifications for task reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _notificationsPlugin.zonedSchedule(
        taskId.hashCode,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: taskId,
      );
    } catch (e) {
      debugPrint('Error scheduling mobile notification: $e');
      await _showMobileNotification(taskId: taskId, title: title, body: body);
    }
  }

  Future<void> _scheduleWebNotification({
    required String taskId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      if (!_webNotificationPermissionGranted) {
        debugPrint('Web notifications not permitted');
        return;
      }

      final now = DateTime.now();
      final delay = scheduledTime.difference(now);

      if (delay.inMilliseconds <= 0) {
        _showWebNotification(title: title, body: body);
        return;
      }

      Timer(Duration(milliseconds: delay.inMilliseconds), () {
        _showWebNotification(title: title, body: body);
      });

      debugPrint('Web notification scheduled for $scheduledTime');
    } catch (e) {
      debugPrint('Error scheduling web notification: $e');
    }
  }

  void _showWebNotification({required String title, required String body}) {
    try {
      html.Notification(title, body: body, icon: '/icons/icon-192x192.png');
    } catch (e) {
      debugPrint('Error showing web notification: $e');
    }
  }

  Future<void> _showMobileNotification({
    required String taskId,
    required String title,
    required String body,
  }) async {
    await _notificationsPlugin.show(
      taskId.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel',
          'Task Reminders',
          channelDescription: 'Notifications for task reminders',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: taskId,
    );
  }

  Future<void> showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    final notification = message.notification;
    final androidDetails = AndroidNotificationDetails(
      'task_channel',
      'Task Reminders',
      channelDescription: 'Notifications for task reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      notification?.title,
      notification?.body,
      notificationDetails,
      payload: message.data['taskId'],
    );
  }

  Future<void> showBackgroundNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    final notification = message.notification;
    final androidDetails = AndroidNotificationDetails(
      'task_channel',
      'Task Reminders',
      channelDescription: 'Notifications for task reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      notification?.title,
      notification?.body,
      notificationDetails,
      payload: message.data['taskId'],
    );
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancelAll();
  }

  void dispose() {
    _notificationStreamController.close();
  }
}
