import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ModernDashboardCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String tag;
  final int delay;

  const ModernDashboardCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.tag,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 600 + delay),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double val, child) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(30 * (1 - val), 0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.gray03.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.red03.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: AppColors.red01, size: 28),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: const TextStyle(
                              color: AppColors.red00,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              color: AppColors.gray00.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.gray03.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: AppColors.gray01,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
