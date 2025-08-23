import 'dart:async';
import 'dart:ui';
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
  bool _isFirebaseMessagingAvailable = true;

  // Helper method to check if running on localhost
  static bool get isLocalhostWeb {
    return kIsWeb &&
        (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1');
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      // Always initialize web notifications, even on localhost
      await _initializeWebNotifications();

      if (isLocalhostWeb) {
        debugPrint(
          '⚠️ Skipping Firebase Messaging initialization on localhost (development)',
        );
        _isFirebaseMessagingAvailable = false;
      } else {
        _isFirebaseMessagingAvailable = true;
      }

      _isInitialized = true;
      return;
    }

    // Initialize timezone for mobile
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

    if (!kIsWeb) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_priority_channel',
        'Task Reminders',
        description: 'Notifications for important task reminders',
        importance: Importance.high,
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
    debugPrint('✅ Notification service initialized with heads-up support');
  }

  Future<void> _initializeWebNotifications() async {
    try {
      // Check current permission status
      if (html.Notification.permission == 'granted') {
        _webNotificationPermissionGranted = true;
        debugPrint('✅ Web notifications permission already granted');
        return;
      } else if (html.Notification.permission == 'denied') {
        debugPrint('❌ Web notifications permission previously denied');
        _webNotificationPermissionGranted = false;
        return;
      }

      // Permission not yet requested or default - request it
      debugPrint('🔄 Requesting web notification permission...');
      final permission = await html.Notification.requestPermission();

      _webNotificationPermissionGranted = permission == 'granted';

      if (_webNotificationPermissionGranted) {
        debugPrint('✅ Web notifications permission granted by user');
      } else {
        debugPrint('❌ Web notifications permission denied by user');
      }
    } catch (e) {
      debugPrint('Error initializing web notifications: $e');
      _webNotificationPermissionGranted = false;
    }
  }

  // Public method to manually request notification permission
  Future<bool> requestWebNotificationPermission() async {
    if (!kIsWeb) return false;

    try {
      final permission = await html.Notification.requestPermission();
      _webNotificationPermissionGranted = permission == 'granted';

      if (_webNotificationPermissionGranted) {
        debugPrint('✅ Web notifications permission granted');
      } else {
        debugPrint('❌ Web notifications permission denied');
      }

      return _webNotificationPermissionGranted;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  // Check if web notifications are available and permitted
  bool get areWebNotificationsAvailable {
    return kIsWeb && _webNotificationPermissionGranted;
  }

  Future<void> _configureLocalTimeZone() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();
    try {
      final localLocation = tz.local;
      tz.setLocalLocation(localLocation);
      debugPrint('✅ Local timezone configured: ${localLocation.name}');
    } catch (e) {
      debugPrint('Error setting timezone: $e');
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
      // If permissions not granted, try to request them
      if (!_webNotificationPermissionGranted) {
        debugPrint('🔄 No web notification permission, requesting...');
        final granted = await requestWebNotificationPermission();

        if (!granted) {
          debugPrint('❌ Cannot schedule notification - permission denied');
          return;
        }
      }

      // Schedule web notification
      await _scheduleWebNotification(
        taskId: taskId,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
      );
      return;
    }

    try {
      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
      final tzNow = tz.TZDateTime.now(tz.local);
      if (tzScheduledTime.isBefore(tzNow)) {
        debugPrint('❌ Skipping notification (time in past)');
        return;
      }

      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'high_priority_channel',
          'Task Reminders',
          channelDescription: 'Notifications for important task reminders',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: null,
          enableVibration: true,
          ticker: 'Task Reminder',
          timeoutAfter: 30000,
          category: AndroidNotificationCategory.reminder,
          fullScreenIntent: true,
          autoCancel: true,
          showWhen: true,
          when: scheduledTime.millisecondsSinceEpoch,
          styleInformation: const DefaultStyleInformation(true, true),
          enableLights: true,
          ledColor: const Color(0xFFFFA000),
          ledOnMs: 1000,
          ledOffMs: 500,
        ),
        iOS: const DarwinNotificationDetails(
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'reminder',
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

      debugPrint('✅ Mobile notification scheduled for: $scheduledTime');
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

      if (delay.inMilliseconds <= 0) {
        debugPrint('Scheduled time is in the past, skipping web notification');
        return;
      }

      Timer(Duration(milliseconds: delay.inMilliseconds), () {
        _showWebNotification(title: title, body: body);
      });

      debugPrint('✅ Web notification scheduled for $scheduledTime');
    } catch (e) {
      debugPrint('Error scheduling web notification: $e');
    }
  }

  void _showWebNotification({required String title, required String body}) {
    try {
      final notification = html.Notification(
        title,
        body: body,
        icon: '/icons/icon-192x192.png',
      );

      // Add click handler
      notification.onClick.listen((event) {
        debugPrint('Web notification clicked: $title');
        _notificationStreamController.add('web_notification_clicked');
      });

      debugPrint('✅ Web notification shown: $title');
    } catch (e) {
      debugPrint('Error showing web notification: $e');
    }
  }

  // Method to show immediate web notification (for testing)
  Future<void> showImmediateWebNotification({
    required String title,
    required String body,
  }) async {
    if (!kIsWeb) return;

    if (!_webNotificationPermissionGranted) {
      debugPrint('🔄 No web notification permission, requesting...');
      final granted = await requestWebNotificationPermission();

      if (!granted) {
        debugPrint('❌ Cannot show notification - permission denied');
        return;
      }
    }

    _showWebNotification(title: title, body: body);
  }

  Future<void> showForegroundNotification(RemoteMessage message) async {
    if (!_isFirebaseMessagingAvailable) {
      debugPrint('⚠️ Firebase Messaging not available (localhost)');
      return;
    }

    final notification = message.notification;
    final androidDetails = AndroidNotificationDetails(
      'high_priority_channel',
      'Task Reminders',
      channelDescription: 'Notifications for important task reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: null,
      enableVibration: true,
      ticker: 'New Task Alert',
      timeoutAfter: 30000,
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: true,
      autoCancel: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      styleInformation: const DefaultStyleInformation(true, true),
      enableLights: true,
      ledColor: const Color(0xFFFFA000),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'reminder',
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
    if (!_isFirebaseMessagingAvailable) {
      debugPrint('⚠️ Firebase Messaging not available (localhost)');
      return;
    }

    final notification = message.notification;
    final androidDetails = AndroidNotificationDetails(
      'high_priority_channel',
      'Task Reminders',
      channelDescription: 'Notifications for important task reminders',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: null,
      enableVibration: true,
      ticker: 'Task Alert',
      timeoutAfter: 30000,
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: true,
      autoCancel: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      styleInformation: const DefaultStyleInformation(true, true),
      enableLights: true,
      ledColor: const Color(0xFFFFA000),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'reminder',
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
