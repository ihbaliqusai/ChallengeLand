import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_update_policy.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/update_required_screen.dart';
import '../services/app_update_service.dart';
import 'game_viewport.dart';

/// Lives above the app's providers, navigator, invitations and game launchers.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({super.key, required this.child, this.service});
  final Widget child;
  final AppUpdateService? service;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  late final AppUpdateService _service;
  AppUpdatePolicy _policy = const AppUpdatePolicy();
  bool _loaded = false, _checking = false, _openingStore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AppUpdateService();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      _policy = await _service
          .cachedPolicy()
          .timeout(const Duration(milliseconds: 800));
    } catch (_) {
      // No verified policy yet: an offline/missing bridge must not lock players out.
    }
    if (!mounted) return;
    setState(() => _loaded = true);
    // Auth preparation and the existing 2.4s splash run alongside this fetch.
    unawaited(_refresh());
  }

  Future<void> _refresh({bool force = false}) async {
    if (_checking || !mounted) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final next = await _service
          .refreshPolicy(force: force)
          .timeout(const Duration(seconds: 7));
      if (!mounted) return;
      setState(() {
        _policy = next;
        if (force && !next.fetchSucceeded) {
          _error = 'تعذّر التحقق من التحديث. تحقق من الاتصال وحاول مجددًا.';
        }
      });
    } catch (_) {
      // Keep a known blocking policy when a later network request fails.
      if (mounted && force) {
        setState(() {
          _error = 'تعذّر التحقق من التحديث. تحقق من الاتصال وحاول مجددًا.';
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openStore() async {
    if (_openingStore) return;
    setState(() {
      _openingStore = true;
      _error = null;
    });
    var opened = false;
    try {
      opened = await _service.openStore().timeout(const Duration(seconds: 5));
    } catch (_) {/* Keep the update screen available for another attempt. */}
    if (!mounted) return;
    setState(() {
      _openingStore = false;
      if (!opened) _error = 'تعذّر فتح المتجر. تحقق من الاتصال وحاول مجددًا.';
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _loaded) unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded && !_policy.requiresUpdate) return widget.child;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Baloo')),
      builder: (context, child) =>
          GameViewport(child: child ?? const SizedBox()),
      home: _loaded
          ? UpdateRequiredScreen(
              policy: _policy,
              checking: _checking,
              openingStore: _openingStore,
              error: _error,
              onUpdate: () => unawaited(_openStore()),
              onRetry: () => unawaited(_refresh(force: true)))
          : const Scaffold(body: SplashPoster()),
    );
  }
}
