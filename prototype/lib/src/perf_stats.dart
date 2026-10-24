import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Collects frame timings for the performance panel.
///
/// [FrameTiming]s give the real build and raster cost of each frame on
/// Android (in profile mode). The browser does not report them, so the
/// interval between frames, measured with a [Ticker], is shown as well.
class PerfStats extends ChangeNotifier {
  PerfStats(TickerProvider vsync) {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _ticker = vsync.createTicker(_onTick)..start();
  }

  late final Ticker _ticker;
  final List<FrameTiming> _timings = [];
  final List<double> _intervals = [];
  Duration? _lastTick;

  /// Average and worst build time (ms) over the last frames.
  ({double avg, double max}) build = (avg: 0, max: 0);

  /// Average and worst raster time (ms) over the last frames.
  ({double avg, double max}) raster = (avg: 0, max: 0);

  /// Frames per second measured from frame intervals.
  double fps = 0;

  /// Worst frame interval (ms) in the window: the visible "hiccup".
  double worstInterval = 0;

  bool get hasEngineTimings => _timings.isNotEmpty;

  void _onTimings(List<FrameTiming> timings) {
    _timings.addAll(timings);
    if (_timings.length > 120) _timings.removeRange(0, _timings.length - 120);
    build = _summary(_timings.map((t) => t.buildDuration));
    raster = _summary(_timings.map((t) => t.rasterDuration));
    // Also logged, so measurements can be collected with `adb logcat`.
    final recent = _summary(timings.map((t) => t.totalSpan));
    debugPrint(
      'PERF frames=${timings.length} '
      'total_avg=${recent.avg.toStringAsFixed(1)} '
      'total_max=${recent.max.toStringAsFixed(1)} '
      'raster_max=${_summary(timings.map((t) => t.rasterDuration)).max.toStringAsFixed(1)}',
    );
  }

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null) return;
    final ms = (elapsed - last).inMicroseconds / 1000;
    // Long gaps mean the app was idle (nothing to draw), not slow.
    if (ms > 250) return;
    _intervals.add(ms);
    if (_intervals.length > 120) _intervals.removeAt(0);
    if (_intervals.length % 15 == 0) {
      final avg = _intervals.reduce((a, b) => a + b) / _intervals.length;
      fps = 1000 / avg;
      worstInterval = _intervals.reduce((a, b) => a > b ? a : b);
      notifyListeners();
    }
  }

  ({double avg, double max}) _summary(Iterable<Duration> durations) {
    final ms = [for (final d in durations) d.inMicroseconds / 1000];
    if (ms.isEmpty) return (avg: 0, max: 0);
    return (
      avg: ms.reduce((a, b) => a + b) / ms.length,
      max: ms.reduce((a, b) => a > b ? a : b),
    );
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ticker.dispose();
    super.dispose();
  }
}
