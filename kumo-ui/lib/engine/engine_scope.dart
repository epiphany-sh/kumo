import 'package:flutter/widgets.dart';

import 'kumo_engine.dart';

/// Provides the [KumoEngine] to the tree. Absent in widget tests, where the
/// UI falls back to mock terminals.
class EngineScope extends InheritedWidget {
  const EngineScope({super.key, required this.engine, required super.child});

  final KumoEngine engine;

  static KumoEngine? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<EngineScope>()?.engine;

  @override
  bool updateShouldNotify(EngineScope oldWidget) => engine != oldWidget.engine;
}
