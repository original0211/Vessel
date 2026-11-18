/// A sample counts as failed when it produced no usable delay — null, or
/// the non-positive value a core reports for a timed-out test.
class DelayStability {
  const DelayStability({
    required this.sampleCount,
    required this.failureCount,
    required this.minDelay,
    required this.maxDelay,
  });

  final int sampleCount;
  final int failureCount;
  final int? minDelay;
  final int? maxDelay;
}

const delayStabilityMinSamples = 3;

DelayStability? summarizeDelayStability(List<int?> samples) {
  if (samples.length < delayStabilityMinSamples) {
    return null;
  }
  var failureCount = 0;
  int? minDelay;
  int? maxDelay;
  for (final sample in samples) {
    if (sample == null || sample <= 0) {
      failureCount++;
      continue;
    }
    if (minDelay == null || sample < minDelay) {
      minDelay = sample;
    }
    if (maxDelay == null || sample > maxDelay) {
      maxDelay = sample;
    }
  }
  return DelayStability(
    sampleCount: samples.length,
    failureCount: failureCount,
    minDelay: minDelay,
    maxDelay: maxDelay,
  );
}
