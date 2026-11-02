import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' show FrameTiming;

import 'package:flutter/widgets.dart';

/// Opt-in on-device measurements. No account data or per-frame logging.
/// Compile with --dart-define=PERF_TRACE=true for the service extension.
abstract final class PerformanceProbe {
  static const enabled = bool.fromEnvironment('PERF_TRACE');
  static const defaultBackground =
      String.fromEnvironment('HOME_BACKGROUND', defaultValue: 'video');
  static final background = ValueNotifier(defaultBackground);
  static final character = ValueNotifier(true);
  static final idle = ValueNotifier(true);
  static final _clock = Stopwatch();
  static final _marks = <String, int>{};
  static final _frames = <FrameTiming>[];
  static var _sampleStart = 0;

  static void initialize() {
    if (!enabled) return;
    _clock.start();
    mark('dart.main');
    WidgetsBinding.instance.addTimingsCallback(_record);
    WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) {
      mark('first.rasterized');
    });
    developer.registerExtension('ext.challengeland.performance',
        (_, args) async {
      final mode = args['background'];
      if (const ['static', 'video'].contains(mode)) {
        background.value = mode!;
      }
      if (args.containsKey('character')) {
        character.value = args['character'] == 'true';
      }
      if (args.containsKey('idle')) idle.value = args['idle'] == 'true';
      if (args['reset'] == 'true') {
        _frames.clear();
        _sampleStart = _clock.elapsedMicroseconds;
      }
      return developer.ServiceExtensionResponse.result(jsonEncode(snapshot()));
    });
  }

  static void mark(String name) {
    if (!enabled) return;
    final micros = _clock.elapsedMicroseconds;
    _marks.putIfAbsent(name, () => micros);
    developer.Timeline.instantSync('CL.$name');
    // One line per startup milestone, rather than logging every rendered frame.
    // ignore: avoid_print
    print('CL_PERF $name ${(micros / 1000).toStringAsFixed(1)}ms');
  }

  static Future<T> measure<T>(
      String name, Future<T> Function() operation) async {
    if (!enabled) return operation();
    final task = developer.TimelineTask()..start('CL.$name');
    mark('$name.begin');
    try {
      return await operation();
    } finally {
      mark('$name.end');
      task.finish();
    }
  }

  static void _record(List<FrameTiming> values) {
    // Bound diagnostics memory even if a profiling build is left running.
    _frames.addAll(values);
    if (_frames.length > 2400) _frames.removeRange(0, _frames.length - 2400);
  }

  static Map<String, Object?> snapshot() {
    Map<String, Object> stats(Iterable<int> values) {
      final sorted = values.toList()..sort();
      if (sorted.isEmpty) return {'count': 0};
      double percentile(double p) =>
          sorted[((sorted.length - 1) * p).round()] / 1000;
      return {
        'count': sorted.length,
        'meanMs': sorted.reduce((a, b) => a + b) / sorted.length / 1000,
        'p50Ms': percentile(.5),
        'p95Ms': percentile(.95),
        'p99Ms': percentile(.99),
        'maxMs': sorted.last / 1000,
        'over16_7Ms': sorted.where((v) => v > 16667).length,
        'over33_3Ms': sorted.where((v) => v > 33333).length,
      };
    }

    final cache = PaintingBinding.instance.imageCache;
    return {
      'elapsedMs': _clock.elapsedMilliseconds,
      'sampleMs': (_clock.elapsedMicroseconds - _sampleStart) / 1000,
      'marksUs': _marks,
      'background': background.value,
      'character': character.value,
      'idle': idle.value,
      'build': stats(_frames.map((f) => f.buildDuration.inMicroseconds)),
      'raster': stats(_frames.map((f) => f.rasterDuration.inMicroseconds)),
      'total': stats(_frames.map((f) => f.totalSpan.inMicroseconds)),
      'imageCacheBytes': cache.currentSizeBytes,
      'imageCacheCount': cache.currentSize,
      'imageLiveCount': cache.liveImageCount,
    };
  }
}
