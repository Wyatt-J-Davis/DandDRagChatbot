import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';

import 'backend_service.dart';

class BackendLifecycleObserver with WidgetsBindingObserver {
  final BackendService backendService;

  BackendLifecycleObserver({required this.backendService});

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await backendService.dispose();
    return AppExitResponse.exit;
  }
}
