import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iz_mobile/core/widgets/app_bottom_nav.dart';
import 'package:iz_mobile/core/theme/app_colors.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          // Main content area
          Positioned.fill(
            child: navigationShell,
          ),
          
          // Floating Bottom Navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNav(
              currentIndex: navigationShell.currentIndex,
              onTap: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
