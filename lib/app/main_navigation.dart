import 'package:flutter/material.dart';

import '../core/theme/grocify_theme.dart';
import '../features/home/home_screen.dart';
import '../features/plan/plan_screen_new.dart';
import '../features/recipes/presentation/recipes_screen.dart';
import '../features/shopping/shopping_list_screen.dart';
import '../features/profile/profile_screen_new.dart';
import '../core/startup/app_startup_coordinator.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

abstract class MainNavigationController {
  int get selectedIndex;
  void setTab(int index);
}

class MainNavigationScope extends InheritedWidget {
  final MainNavigationController controller;

  const MainNavigationScope({
    super.key,
    required this.controller,
    required super.child,
  });

  static MainNavigationController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainNavigationScope>()?.controller;
  }

  @override
  bool updateShouldNotify(MainNavigationScope oldWidget) => false;
}

class _MainNavigationState extends State<MainNavigation> implements MainNavigationController {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(), // Index 0: Home
    const RecipesScreen(), // Index 1: Rezepte
    const PlanScreenNew(), // Index 2: Planen
    const ShoppingListScreen(), // Index 3: Einkaufsliste
    const ProfileScreenNew(), // Index 4: Profil
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStartupCoordinator.instance.runIfNeeded(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = _selectedIndex.clamp(0, _screens.length - 1);

    return MainNavigationScope(
      controller: this,
      child: Scaffold(
        body: IndexedStack(
          index: safeIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: GrocifyTheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (index) {
              setTab(index);
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 76,

            // WICHTIG: Verhindert, dass Labels beim Selektieren "springen"
            // und sorgt für stabile Höhe/Zeilenumbruch-Verhalten.
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,

            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, size: 24),
                selectedIcon: Icon(Icons.home_rounded, size: 24),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.restaurant_menu_outlined, size: 24),
                selectedIcon: Icon(Icons.restaurant_menu_rounded, size: 24),
                label: 'Rezepte',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined, size: 24),
                selectedIcon: Icon(Icons.calendar_month_rounded, size: 24),
                label: 'Planen',
              ),

              NavigationDestination(
                icon: Icon(Icons.checklist_outlined, size: 24),
                selectedIcon: Icon(Icons.checklist_rounded, size: 24),
                label: 'Einkaufsliste',
              ),

              NavigationDestination(
                icon: Icon(Icons.person_outline, size: 24),
                selectedIcon: Icon(Icons.person_rounded, size: 24),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void setTab(int index) {
    setState(() => _selectedIndex = index.clamp(0, _screens.length - 1));
  }

  @override
  int get selectedIndex => _selectedIndex;
}


