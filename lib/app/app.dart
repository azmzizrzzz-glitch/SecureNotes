import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/lock_screen.dart';

class SecureNotesApp extends StatelessWidget {
  const SecureNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureNotes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        primaryColor: const Color(0xFF6C63FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF00D9FF),
          surface: Color(0xFF1A1A2E),
          background: Color(0xFF0A0A0F),
          error: Color(0xFFFF6B6B),
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          elevation: 0,
        ),
      ),
      home: const LockScreen(),
    );
  }
}
