import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_colors.dart';
import 'core/navigation/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['VITE_FIREBASE_API_KEY'] ?? '',
      authDomain: dotenv.env['VITE_FIREBASE_AUTH_DOMAIN'],
      projectId: dotenv.env['VITE_FIREBASE_PROJECT_ID'] ?? '',
      storageBucket: dotenv.env['VITE_FIREBASE_STORAGE_BUCKET'],
      messagingSenderId: dotenv.env['VITE_FIREBASE_MESSAGING_SENDER_ID'] ?? '',
      appId: dotenv.env['VITE_FIREBASE_APP_ID'] ?? '',
      measurementId: dotenv.env['VITE_FIREBASE_MEASUREMENT_ID'],
    ),
  );

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
