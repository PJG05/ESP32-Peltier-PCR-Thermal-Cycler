class PCRTemperatureSample {
  final int sequence;
  final double elapsedSeconds;
  final double temperature;
  final double target;
  final int cycle;
  final String stageName;
  final String phase;
  final int holdRemainingMs;

  const PCRTemperatureSample({
    this.sequence = 0,
    required this.elapsedSeconds,
    required this.temperature,
    required this.target,
    required this.cycle,
    required this.stageName,
    required this.phase,
    required this.holdRemainingMs,
  });

  factory PCRTemperatureSample.fromJson(
    Map<String, dynamic> json,
  ) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    int toInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return PCRTemperatureSample(
      sequence: toInt(json['seq']),
      elapsedSeconds: toDouble(json['elapsedMs']) / 1000.0,
      temperature: toDouble(json['temperature']),
      target: toDouble(json['target']),
      cycle: toInt(json['cycle']),
      stageName: json['stageName']?.toString() ?? 'Idle',
      phase: json['phase']?.toString() ?? '',
      holdRemainingMs: toInt(json['holdRemainingMs']),
    );
  }
}

class TelemetryBatch {
  final int runId;
  final int latestSequence;
  final int oldestSequence;
  final bool gap;
  final bool runChanged;
  final bool hasMore;
  final List<PCRTemperatureSample> samples;

  const TelemetryBatch({
    required this.runId,
    required this.latestSequence,
    required this.oldestSequence,
    required this.gap,
    required this.runChanged,
    required this.hasMore,
    required this.samples,
  });

  factory TelemetryBatch.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final rawSamples = json['samples'];

    final samples = <PCRTemperatureSample>[];

    if (rawSamples is List) {
      for (final item in rawSamples) {
        if (item is Map) {
          samples.add(
            PCRTemperatureSample.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return TelemetryBatch(
      runId: toInt(json['runId']),
      latestSequence: toInt(json['latestSequence']),
      oldestSequence: toInt(json['oldestSequence']),
      gap: json['gap'] == true,
      runChanged: json['runChanged'] == true,
      hasMore: json['hasMore'] == true,
      samples: samples,
    );
  }
}
