import 'package:kfusion/common/constant.dart';

enum SpeedTestPhase { running, succeeded, failed }

class SpeedTestState {
  const SpeedTestState._(
    this.phase, {
    this.mbps,
    this.totalBytes = 0,
    this.error,
  });

  const SpeedTestState.running() : this._(SpeedTestPhase.running);

  const SpeedTestState.succeeded({
    required double mbps,
    required int totalBytes,
  }) : this._(SpeedTestPhase.succeeded, mbps: mbps, totalBytes: totalBytes);

  const SpeedTestState.failed({String? error})
    : this._(SpeedTestPhase.failed, error: error);

  final SpeedTestPhase phase;
  final double? mbps;
  final int totalBytes;

  /// Why a failed test failed, carrying the Core's per-source errors; a
  /// running or succeeded test has none.
  final String? error;
}

String formatSpeedMbps(double mbps) {
  if (mbps >= 100) {
    return mbps.toStringAsFixed(0);
  }
  return mbps.toStringAsFixed(1);
}

bool speedTestEntryEnabled({
  required bool singBoxBearing,
  required bool windowsPlatform,
}) {
  return !singBoxBearing || windowsPlatform;
}

class SpeedTestWindow {
  const SpeedTestWindow(this.bytes, this.duration);

  final int bytes;
  final Duration duration;
}

/// Splits a download into the discarded warmup and the measured window,
/// with the same bounds as the meter in core/speedtest.go.
class SpeedTestMeter {
  SpeedTestMeter({required DateTime startedAt}) : _startedAt = startedAt;

  final DateTime _startedAt;
  int _totalBytes = 0;
  bool _warmupDone = false;
  int _warmupBytes = 0;
  Duration _warmupFor = Duration.zero;

  int get totalBytes => _totalBytes;

  bool get warmupDone => _warmupDone;

  void add(int bytes, DateTime at) {
    _totalBytes += bytes;
    if (_warmupDone) {
      return;
    }
    final elapsed = at.difference(_startedAt);
    if (elapsed >= speedTestWarmupDuration ||
        _totalBytes >= speedTestWarmupBytes) {
      _warmupDone = true;
      _warmupBytes = _totalBytes;
      _warmupFor = elapsed;
    }
  }

  SpeedTestWindow window(DateTime at) {
    if (!_warmupDone) {
      return const SpeedTestWindow(0, Duration.zero);
    }
    return SpeedTestWindow(
      _totalBytes - _warmupBytes,
      at.difference(_startedAt) - _warmupFor,
    );
  }
}

double speedMbpsForWindow(int windowBytes, Duration window) {
  if (windowBytes <= 0 || window <= Duration.zero) {
    return 0;
  }
  final seconds = window.inMicroseconds / Duration.microsecondsPerSecond;
  return windowBytes * 8 / seconds / 1e6;
}

bool speedWindowMeasurable(SpeedTestWindow window) {
  return window.bytes > 0 && window.duration >= speedTestMinWindowDuration;
}
