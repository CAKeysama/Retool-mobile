import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class WIPScreen extends StatelessWidget {
  final String title;
  const WIPScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(
                color: AppColors.black01, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              duration: const Duration(seconds: 2),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double val, child) {
                return Transform.rotate(
                  angle: val * 6.28,
                  child: const Icon(Icons.settings_suggest_rounded,
                      size: 80, color: AppColors.red03),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '[WIP] $title',
              style: const TextStyle(
                color: AppColors.gray01,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gray03.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'LABORATÓRIO DE DESENVOLVIMENTO',
                style: TextStyle(
                    color: AppColors.gray01,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
