import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/constants/app_config.dart';
import 'core/utils/sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.useMockData) {
    try {
      // TODO: Update Firebase project to match new package name.
      await Firebase.initializeApp();
    } catch (_) {
      // TODO: Add Firebase options with FlutterFire CLI before production.
    }
  }

  unawaited(SoundService.instance.init());

  runApp(const ChallengeLandApp());
}
