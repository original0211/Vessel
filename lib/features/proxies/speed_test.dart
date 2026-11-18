enum SpeedTestPhase { running, succeeded, failed }

class SpeedTestState {
  const SpeedTestState._(this.phase, {this.mbps, this.totalBytes = 0});

  const SpeedTestState.running() : this._(SpeedTestPhase.running);

  const SpeedTestState.succeeded({
    required double mbps,
    required int totalBytes,
  }) : this._(SpeedTestPhase.succeeded, mbps: mbps, totalBytes: totalBytes);

  const SpeedTestState.failed() : this._(SpeedTestPhase.failed);

  final SpeedTestPhase phase;
  final double? mbps;
  final int totalBytes;
}

String formatSpeedMbps(double mbps) {
  if (mbps >= 100) {
    return mbps.toStringAsFixed(0);
  }
  return mbps.toStringAsFixed(1);
}
