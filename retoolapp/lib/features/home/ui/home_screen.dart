import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/services/firestore_service.dart';
import '../widgets/dashboard_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.bgGradient,
          ),
        ),
        child: Stack(
          children: [
            // Watermark Design
            Positioned(
              right: -50,
              top: 100,
              child: Opacity(
                opacity: 0.03,
                child: RotatedBox(
                  quarterTurns: 1,
                  child: const Text(
                    'BALDAN',
                    style: TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      color: AppColors.black00,
                      letterSpacing: 20,
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    // Refined Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.help_outline_rounded, size: 18),
                          label: const Text('Sobre o Projeto'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.gray01,
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            backgroundColor: AppColors.gray03.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Logo with Animation
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, double value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Re',
                                  style: TextStyle(
                                    color: AppColors.black01,
                                    fontSize: 56,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Tool',
                                  style: TextStyle(
                                    color: AppColors.red00,
                                    fontSize: 56,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.red00.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Gestão de Dispositivos e Ferramentas Industriais',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.gray00,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),

                    // Ultra-polished Search Bar
                    _buildPolishedSearchBar(),

                    const SizedBox(height: 24),

                    // Action Buttons with better styling
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildActionButton(
                          label: 'Buscar dispositivos',
                          onPressed: () {},
                          isPrimary: false,
                        ),
                        const SizedBox(width: 16),
                        _buildAddButton(onPressed: () {}),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Dashboard Section Header
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'RESUMO GERAL',
                        style: TextStyle(
                          color: AppColors.gray01,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // High-quality Dashboard Cards with Real-time data
                    StreamBuilder<int>(
                      stream: _firestoreService.getDispositivosCount(),
                      builder: (context, snapshot) {
                        return ModernDashboardCard(
                          icon: Icons.inventory_2_outlined,
                          value: snapshot.hasData ? snapshot.data.toString() : '...',
                          label: 'Dispositivos Registrados',
                          tag: 'D',
                          delay: 200,
                        );
                      }
                    ),
                    StreamBuilder<int>(
                      stream: _firestoreService.getUtilizacoesCount(),
                      builder: (context, snapshot) {
                        return ModernDashboardCard(
                          icon: Icons.build_outlined,
                          value: snapshot.hasData ? snapshot.data.toString() : '...',
                          label: 'Utilizações Ativas',
                          tag: 'U',
                          delay: 400,
                        );
                      }
                    ),
                    StreamBuilder<int>(
                      stream: _firestoreService.getCategoriasCount(),
                      builder: (context, snapshot) {
                        return ModernDashboardCard(
                          icon: Icons.sell_outlined,
                          value: snapshot.hasData ? snapshot.data.toString() : '...',
                          label: 'Categorias de Ferramentas',
                          tag: 'C',
                          delay: 600,
                        );
                      }
                    ),

                    const SizedBox(height: 100), // Space for floating nav
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolishedSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.red00.withOpacity(0.12),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 0,
            spreadRadius: -2,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: TextField(
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Pesquisar dispositivos, códigos...',
          hintStyle: TextStyle(
              color: AppColors.gray01.withOpacity(0.5), fontSize: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(Icons.search_rounded,
                color: AppColors.red00.withOpacity(0.6)),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide:
                BorderSide(color: AppColors.red00.withOpacity(0.1), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
                color: AppColors.red00.withOpacity(0.05), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.red00, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildActionButton(
      {required String label,
      required VoidCallback onPressed,
      required bool isPrimary}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color:
                isPrimary ? AppColors.red00 : AppColors.gray03.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isPrimary ? Colors.transparent : AppColors.gray02,
                width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? Colors.white : AppColors.black01,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton({required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.red00,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.red00.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}
