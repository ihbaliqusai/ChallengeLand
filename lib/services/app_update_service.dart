import 'package:flutter/services.dart';

import '../models/app_update_policy.dart';

class AppUpdateService {
  static const _channel = MethodChannel('challengeland/app-update');

  Future<AppUpdatePolicy> cachedPolicy() async => AppUpdatePolicy.fromMap(
      await _channel.invokeMapMethod<String, dynamic>('getPolicy') ?? {});

  Future<AppUpdatePolicy> refreshPolicy({bool force = false}) async =>
      AppUpdatePolicy.fromMap(await _channel.invokeMapMethod<String, dynamic>(
              'refreshPolicy', {'force': force}) ??
          {});

  Future<bool> openStore() async =>
      await _channel.invokeMethod<bool>('openStore') == true;
}
