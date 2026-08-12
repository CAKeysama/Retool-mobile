import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/shared/ui/wip_screen.dart';

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
                _buildNavItem(Icons.inventory_2_rounded,
                    Icons.inventory_2_outlined, 1),
                _buildNavItem(Icons.build_rounded, Icons.build_outlined, 2),
                _buildNavItem(Icons.sell_rounded, Icons.sell_outlined, 3),
                _buildNavItem(
                    Icons.account_circle_rounded, Icons.account_circle_outlined, 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
      IconData activeIcon, IconData inactiveIcon, int index) {
    bool isSelected = _selectedIndex == index;
    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.red00.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(isSelected ? activeIcon : inactiveIcon, size: 26),
      ),
      label: '',
    );
  }
}
