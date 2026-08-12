import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'core/navigation/main_navigation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReTool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.white00,
        ),
        scaffoldBackgroundColor: AppColors.white00,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}
