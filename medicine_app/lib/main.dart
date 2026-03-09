import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/medicine/view/medicine_screen.dart';

void main() {
  runApp(const MedicineApp());
}

class MedicineApp extends StatelessWidget {
  const MedicineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const MedicineScreen(),
    );
  }
}