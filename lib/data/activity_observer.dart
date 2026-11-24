import 'package:flutter/widgets.dart';

import 'study_repository.dart';

/// Logs every named screen the learner opens ("Opened Topic: Vital Signs").
/// Routes are named with `RouteSettings(name:, arguments:)` where they are
/// pushed; the argument, if any, becomes the log line's detail.
class ActivityObserver extends NavigatorObserver {
  ActivityObserver(this.study);

  final StudyRepository study;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    // The root route is "/"; it's covered by "App opened".
    if (name == null || name.startsWith('/')) return;
    study.logActivity('Opened $name', route.settings.arguments?.toString());
  }
}
