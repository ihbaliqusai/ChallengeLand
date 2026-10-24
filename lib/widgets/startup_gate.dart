import 'package:flutter/material.dart';

/// Draws a focusable Flutter window before starting platform initialization.
class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.initialize,
    required this.loading,
    required this.ready,
  });

  final Future<void> Function() initialize;
  final Widget loading;
  final Widget ready;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await widget.initialize();
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) => _ready ? widget.ready : widget.loading;
}
