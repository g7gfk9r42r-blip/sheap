import 'package:flutter/material.dart';

/// App-wide globals that do not affect UI/layout.
/// Used for background prefetching (needs a context) without wiring through widgets.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();


