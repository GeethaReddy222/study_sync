import 'package:flutter/material.dart';
import 'package:study_sync/screens/add_task_screen.dart';
import 'package:study_sync/screens/main_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  MyApp({super.key});

  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Study Sync',
      theme: studySyncTheme,
      home: AddTaskScreen(),
    );
  }

  final ThemeData studySyncTheme = ThemeData(
    primaryColor: Color(0xFF4A90E2),
    scaffoldBackgroundColor: Color(0xFFF5F7FA),
    fontFamily: 'Poppins',
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        
        backgroundColor: Color(0xFF4A90E2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF4A90E2)),
        borderRadius: BorderRadius.circular(12),
      ),
      labelStyle: TextStyle(color: Color(0xFF90A4AE)),
    ),
  );
}
