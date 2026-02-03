/// GrocifyScaffold
/// Einheitliches Scaffold mit AppBar-Style und Hintergrundfarbe
import 'package:flutter/material.dart';
import '../theme/grocify_theme.dart';

class GrocifyScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showAppBar;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;

  const GrocifyScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showAppBar = true,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? GrocifyTheme.background,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: showAppBar && title != null
          ? AppBar(
              title: Text(title!),
              actions: actions,
              elevation: 0,
              scrolledUnderElevation: 0,
            )
          : null,
      body: SafeArea(
        child: body,
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

