// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'registro_screen.dart';
import 'historial_screen.dart';
import 'estadisticas_screen.dart';
import 'analisis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _screens = [
    RegistroScreen(),
    HistorialScreen(),
    EstadisticasScreen(),
    AnalisisScreen(),
  ];

  static const _items = [
    (Icons.casino_outlined,    Icons.casino_rounded,    ''),
    (Icons.history_outlined,   Icons.history_rounded,   ''),
    (Icons.bar_chart_outlined, Icons.bar_chart_rounded, ''),
    (Icons.insights_outlined,  Icons.insights_rounded,  ''),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.bgLight,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.textSecondary,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: _items.map((e) {
            final (iconOut, iconFilled, label) = e;
            return BottomNavigationBarItem(
              icon: Icon(iconOut),
              activeIcon: Icon(iconFilled),
              label: label,
            );
          }).toList(),
        ),
      ),
    );
  }
}
