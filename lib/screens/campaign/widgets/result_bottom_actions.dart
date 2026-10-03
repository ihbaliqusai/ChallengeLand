import 'package:flutter/material.dart';

class ResultBottomActions extends StatelessWidget {
  const ResultBottomActions({
    super.key,
    required this.onMap,
    required this.onRetry,
    this.onNext,
    this.nextLabel = 'المرحلة التالية',
    this.launching = false,
  });

  final VoidCallback onMap;
  final VoidCallback onRetry;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool launching;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: launching ? null : onNext ?? onRetry,
                icon: launching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(onNext != null
                        ? Icons.arrow_back_rounded
                        : Icons.refresh_rounded),
                label: Text(launching
                    ? 'جارٍ البدء...'
                    : onNext != null
                        ? nextLabel
                        : 'حاول مرة أخرى'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC857),
                  foregroundColor: const Color(0xFF311300),
                  disabledBackgroundColor: const Color(0xFF536178),
                  disabledForegroundColor: Colors.white70,
                  minimumSize: const Size(0, 50),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: [
                if (onNext != null)
                  TextButton.icon(
                    onPressed: launching ? null : onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('تحسين النجوم'),
                    style: _secondaryStyle,
                  ),
                TextButton.icon(
                  onPressed: launching ? null : onMap,
                  icon: const Icon(Icons.map_rounded, size: 20),
                  label: const Text('خريطة المراحل'),
                  style: _secondaryStyle,
                ),
              ],
            ),
          ],
        ),
      );

  static final ButtonStyle _secondaryStyle = TextButton.styleFrom(
    foregroundColor: const Color(0xFFBDEBFF),
    minimumSize: const Size(48, 44),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
  );
}
