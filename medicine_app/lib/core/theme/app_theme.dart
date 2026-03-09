import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0
      ),
      inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder()
      )
  );
}