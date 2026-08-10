import 'package:flutter/material.dart';
import 'dart:ui';

void main() {
  runApp(const MyApp());
}

class AppColors {
  // Paleta Principal do Sistema
  static const Color red00 = Color(0xFFE40D2C);
  static const Color red01 = Color(0xFF8C1A17);
  static const Color red02 = Color(0xFFFF798D);
  static const Color red03 = Color(0xFFFCC4CC);
  static const Color gray00 = Color(0xFF4A4A4A);
  static const Color gray01 = Color(0xFF808080);
  static const Color gray02 = Color(0xFFD6D6D6);
  static const Color gray03 = Color(0xFFE8E7E7);
  static const Color black00 = Color(0xFF000000);
  static const Color black01 = Color(0xFF2F2F2F);
  static const Color white00 = Color(0xFFFFFFFE);

  // Mapeamento Semântico
  static const Color primary = red00;
  static const Color textTitle = red00;
  static const Color textBody = gray00;
  static const Color textDark = black01;
  static const Color surfaceBg = white00;
  static const Color border = gray02;
  static const Color hover = gray03;

  // Background Gradient
  static const List<Color> bgGradient = [
    Color(0xFFFFFFFF),
    Color(0xFFFDFDFD),
    Color(0xFFF8F8F8),
  ];
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double x2l = 48.0;

  static const double radiusSm = 8.0;
  static const double radius = 16.0;
  static const double radiusLg = 24.0;
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
        fontFamily: 'Inter', // Usando Inter/Roboto se disponível, senão padrão
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const WIPScreen(title: 'Dispositivos'),
    const WIPScreen(title: 'Utilizações'),
    const WIPScreen(title: 'Categorias'),
    const WIPScreen(title: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.gray01,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              elevation: 0,
              items: [
                _buildNavItem(Icons.home_rounded, Icons.home_outlined, 0),
                _buildNavItem(Icons.inventory_2_rounded, Icons.inventory_2_outlined, 1),
                _buildNavItem(Icons.build_rounded, Icons.build_outlined, 2),
                _buildNavItem(Icons.sell_rounded, Icons.sell_outlined, 3),
                _buildNavItem(Icons.account_circle_rounded, Icons.account_circle_outlined, 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData activeIcon, IconData inactiveIcon, int index) {
    bool isSelected = _selectedIndex == index;
    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.red00.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(isSelected ? activeIcon : inactiveIcon, size: 26),
      ),
      label: '',
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                  child: Text(
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
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: AppColors.gray03.withOpacity(0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

                    // High-quality Dashboard Cards
                    _buildModernDashboardCard(
                      icon: Icons.inventory_2_outlined,
                      value: '21',
                      label: 'Dispositivos Registrados',
                      tag: 'D',
                      delay: 200,
                    ),
                    _buildModernDashboardCard(
                      icon: Icons.build_outlined,
                      value: '6',
                      label: 'Utilizações Ativas',
                      tag: 'U',
                      delay: 400,
                    ),
                    _buildModernDashboardCard(
                      icon: Icons.sell_outlined,
                      value: '3',
                      label: 'Categorias de Ferramentas',
                      tag: 'C',
                      delay: 600,
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
          hintStyle: TextStyle(color: AppColors.gray01.withOpacity(0.5), fontSize: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(Icons.search_rounded, color: AppColors.red00.withOpacity(0.6)),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: AppColors.red00.withOpacity(0.1), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: AppColors.red00.withOpacity(0.05), width: 1.5),
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

  Widget _buildActionButton({required String label, required VoidCallback onPressed, required bool isPrimary}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: isPrimary ? AppColors.red00 : AppColors.gray03.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isPrimary ? Colors.transparent : AppColors.gray02, width: 1),
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

  Widget _buildModernDashboardCard({
    required IconData icon,
    required String value,
    required String label,
    required String tag,
    required int delay,
  }) {
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

class WIPScreen extends StatelessWidget {
  final String title;
  const WIPScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: AppColors.black01, fontWeight: FontWeight.w800)),
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
                  child: Icon(Icons.settings_suggest_rounded, size: 80, color: AppColors.red03),
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
                style: TextStyle(color: AppColors.gray01, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
