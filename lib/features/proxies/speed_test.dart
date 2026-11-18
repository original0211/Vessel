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
