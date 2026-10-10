import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// A deadline applies only to the first result, not to an idle live feed.
/// The subscription stays alive so a late connection can recover automatically.
class SocialStreamBuilder<T> extends StatefulWidget {
  const SocialStreamBuilder(
      {super.key,
      required this.stream,
      required this.builder,
      required this.onRetry,
      this.initialTimeout = const Duration(seconds: 10)});
  final Stream<T> stream;
  final AsyncWidgetBuilder<T> builder;
  final VoidCallback onRetry;
  final Duration initialTimeout;
  @override
  State<SocialStreamBuilder<T>> createState() => _SocialStreamBuilderState<T>();
}

class _SocialStreamBuilderState<T> extends State<SocialStreamBuilder<T>> {
  Timer? _deadline;
  bool _timedOut = false;
  @override
  void initState() {
    super.initState();
    _startDeadline();
  }

  void _startDeadline() {
    _deadline?.cancel();
    _timedOut = false;
    _deadline = Timer(widget.initialTimeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void didUpdateWidget(covariant SocialStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stream != oldWidget.stream) _startDeadline();
  }

  @override
  void dispose() {
    _deadline?.cancel();
    super.dispose();
  }

  String _message(Object? error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'خدمة الأصدقاء غير متاحة لهذا الحساب حاليًا. حاول مرة أخرى لاحقًا.';
        case 'failed-precondition':
          return 'خدمة الأصدقاء قيد التهيئة. حاول مرة أخرى بعد قليل.';
      }
    }
    return 'تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.';
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
        stream: widget.stream,
        builder: (context, snapshot) {
          if (snapshot.hasError ||
              (!snapshot.hasData &&
                  (_timedOut ||
                      snapshot.connectionState == ConnectionState.done))) {
            _deadline?.cancel();
            return Center(
                child: SingleChildScrollView(
                    child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.white70),
                const SizedBox(height: 12),
                Text(_message(snapshot.error), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة')),
              ]),
            )));
          }
          if (snapshot.hasData) {
            _deadline?.cancel();
            return widget.builder(context, snapshot);
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
}
