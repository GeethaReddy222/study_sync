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
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      await _initializeWebNotifications();
      _isInitialized = true;
      return;
    }

    // Initialize timezone
    await _configureLocalTimeZone();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    // Create notification channel for Android
    if (!kIsWeb) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'task_channel', // id
        'Task Reminders', // title
        description: 'Notifications for task reminders',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _notificationStreamController.add(response.payload);
      },
    );

    _isInitialized = true;
    debugPrint('✅ Notification service initialized');
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
      // Use the device's local timezone directly
      final localLocation = tz.local;
      tz.setLocalLocation(localLocation);
      debugPrint('✅ Local timezone configured: ${localLocation.name}');
    } catch (e) {
      debugPrint('Error setting timezone: $e');
      // Fallback to UTC
      tz.setLocalLocation(tz.getLocation('UTC'));
      debugPrint('✅ Fallback to UTC timezone');
    }
  }

  Future<void> scheduleTaskNotification({
    required String taskId,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

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
      // Convert the DateTime to TZDateTime in the local timezone
      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
      final tzNow = tz.TZDateTime.now(tz.local);

      if (tzScheduledTime.isBefore(tzNow)) {
        debugPrint('❌ Skipping notification (time in past)');
        return;
      }

      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel', // same as channel id
          'Task Reminders', // same as channel name
          channelDescription: 'Notifications for task reminders',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notificationsPlugin.zonedSchedule(
        taskId.hashCode,
        title,
        body,
        tzScheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: taskId,
      );

      debugPrint('✅ Notification scheduled (local): $scheduledTime');
      debugPrint('✅ Notification scheduled (tz): $tzScheduledTime');
      debugPrint('✅ Current time (tz): $tzNow');
      debugPrint('✅ Time difference: ${tzScheduledTime.difference(tzNow)}');
    } catch (e) {
      debugPrint('❌ Error scheduling notification: $e');
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

      // If the scheduled time is in the past, don't schedule
      if (delay.inMilliseconds <= 0) {
        debugPrint('Scheduled time is in the past, skipping web notification');
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

  // Add this method to test immediate notifications
  Future<void> showTestNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (kIsWeb) return;

    try {
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel',
          'Task Reminders',
          channelDescription: 'Notifications for task reminders',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notificationsPlugin.show(
        9999, // Test ID
        'Test Notification',
        'This is a test notification sent at ${DateTime.now()}',
        notificationDetails,
        payload: 'test',
      );

      debugPrint('✅ Test notification shown successfully');
    } catch (e) {
      debugPrint('❌ Error showing test notification: $e');
    }
  }

  Future<void> showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    final notification = message.notification;
    final androidDetails = const AndroidNotificationDetails(
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
      iOS: const DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

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
    final androidDetails = const AndroidNotificationDetails(
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
      iOS: const DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

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
