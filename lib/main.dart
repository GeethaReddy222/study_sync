import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:study_sync/providers/user_provider.dart';
import 'package:study_sync/screens/main_screen.dart';
import 'package:study_sync/services/notification/notification_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final isLocalhostWeb =
      Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1';
  if (!isLocalhostWeb) {
    await NotificationService().showBackgroundNotification(message);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize notification service with error handling
    try {
      await NotificationService().initialize();
    } catch (e) {
      debugPrint('Notification service initialization failed: $e');
    }

    // Check if we're on localhost web before initializing Firebase Messaging
    final isLocalhostWeb =
        Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1';

    if (!isLocalhostWeb) {
      // Request notification permissions only if not on localhost
      final messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('Permission status: ${settings.authorizationStatus}');

      // Get token for debugging
      final token = await messaging.getToken();
      debugPrint('FCM Token: $token');

      // Set background handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground message received: ${message.messageId}');
        NotificationService().showForegroundNotification(message);
      });

      // Handle when app is in background but not terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Message opened from background: ${message.messageId}');
      });
    } else {
      debugPrint('⚠️ Skipping Firebase Messaging initialization on localhost');
    }

    runApp(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('Initialization error: $e'))),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Study Sync',
      theme: _studySyncTheme,
      home: const MainScreenWithNotificationHandler(),
    );
  }

  static final ThemeData _studySyncTheme = ThemeData(
    primarySwatch: Colors.indigo,
    scaffoldBackgroundColor: Colors.grey[50],
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.indigo.shade400,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo.shade400,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
    ),
  );
}

class MainScreenWithNotificationHandler extends StatefulWidget {
  const MainScreenWithNotificationHandler({super.key});

  @override
  State<MainScreenWithNotificationHandler> createState() =>
      _MainScreenWithNotificationHandlerState();
}

class _MainScreenWithNotificationHandlerState
    extends State<MainScreenWithNotificationHandler> {
  StreamSubscription<String?>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeNotificationHandler();
    _checkInitialNotification();
  }

  void _initializeNotificationHandler() {
    _notificationSubscription = NotificationService().notificationStream.listen(
      (taskId) {
        if (taskId != null && mounted) {
          _handleNotificationTap(taskId);
        }
      },
      onError: (error) {
        debugPrint('Notification stream error: $error');
      },
    );
  }

  Future<void> _checkInitialNotification() async {
    // Skip on localhost web
    final isLocalhostWeb =
        Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1';
    if (isLocalhostWeb) return;

    // Check if app was launched by a notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && mounted) {
      setState(() {});

      // Delay handling to ensure the app is fully initialized
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final taskId = initialMessage.data['taskId'];
        if (taskId != null) {
          _handleNotificationTap(taskId);
        }
      });
    }
  }

  void _handleNotificationTap(String taskId) {
    // You might want to navigate to the specific task instead of showing a dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Reminder'),
        content: Text('You tapped on a notification for task $taskId'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const MainScreen();
  }
}
