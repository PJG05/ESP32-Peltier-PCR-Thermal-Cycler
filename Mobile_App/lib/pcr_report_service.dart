import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/live_status.dart';
import '../models/pcr_program.dart';
import '../models/pcr_stage.dart';
import '../models/pcr_temperature_sample.dart';

class PCRReportService {
  static String _stageTagForIndex(int stageRowsLength) {
    // stageRows already contains Initial Denaturation (T1), so the first
    // cycling stage is T2, then T3 and T4 for the standard three-stage cycle.
    final tagNumber = stageRowsLength + 1;
    return 'T$tagNumber';
  }

  //==================================================
  // GENERATE COMPLETE PCR REPORT
  //==================================================

  static Future<Uint8List> generateReport({
    required PCRProgram program,
    required List<PCRTemperatureSample> reportTemperatureSamples,
    required DateTime runStartedAt,
    required DateTime generatedAt,
    LiveStatus? finalStatus,
  }) async {
    final pdf = pw.Document(
      title: 'PCR Run Report - ${program.name}',
      author: 'PCR Controller',
      subject: 'PCR Thermocycler Run Report',
    );

    final fileName = buildFileName(program.name, generatedAt);
    final duration = generatedAt.difference(runStartedAt);
    final profile = _buildProcessedProfile(
      program: program,
      samples: reportTemperatureSamples,
    );

    final stageRows = <List<String>>[
      [
        'Initial Denaturation (T1)',
        '${program.initialTemp.toStringAsFixed(2)} °C',
        _formatSeconds(program.initialHold),
      ],
    ];

    for (final stage in program.stages) {
      stageRows.add([
        '${stage.stageName} (${_stageTagForIndex(stageRows.length)})',
        '${stage.temperature.toStringAsFixed(2)} °C',
        _formatSeconds(stage.holdTime),
      ]);
    }

    stageRows.add([
      'Final Extension (T5)',
      '${program.finalTemp.toStringAsFixed(2)} °C',
      _formatSeconds(program.finalHold),
    ]);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 100,
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(
                color: PdfColors.grey300,
                width: 1,
              ),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'PCR CONTROLLER',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.Text(
                'PCR Run Report',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(
                color: PdfColors.grey300,
                width: 1,
              ),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                fileName,
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          //================================================
          // TITLE
          //================================================
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'PCR RUN REPORT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  program.name.isEmpty ? 'PCR Program' : program.name,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Generated: ${_formatDateTime(generatedAt)}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 25),

          //================================================
          // RUN SUMMARY
          //================================================
          pw.Header(level: 1, text: 'Run Summary'),
          pw.TableHelper.fromTextArray(
            headers: const ['Parameter', 'Value'],
            data: [
              [
                'Program',
                program.name.isEmpty ? 'PCR Program' : program.name,
              ],
              ['Run Started', _formatDateTime(runStartedAt)],
              ['Report Generated', _formatDateTime(generatedAt)],
              ['Run Duration', _formatDuration(duration)],
              ['Number of Cycles', program.cycles.toString()],
              [
                'Report Cycle Profile',
                reportTemperatureSamples.isEmpty
                    ? 'No raw samples available'
                    : 'Average of ${profile.cyclesUsed} cycles',
              ],
              [
                'Final ESP32 State',
                finalStatus == null
                    ? 'No status available'
                    : finalStatus.running
                    ? 'Running'
                    : 'Stopped / Completed',
              ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blue700,
            ),
            cellPadding: const pw.EdgeInsets.all(6),
            border: pw.TableBorder.all(color: PdfColors.grey300),
          ),
          pw.SizedBox(height: 20),

          //================================================
          // PROGRAM SETTINGS
          //================================================
          pw.Header(level: 1, text: 'PCR Program Settings'),
          pw.TableHelper.fromTextArray(
            headers: const ['Stage', 'Temperature', 'Hold Time'],
            data: stageRows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blue700,
            ),
            cellPadding: const pw.EdgeInsets.all(6),
            border: pw.TableBorder.all(color: PdfColors.grey300),
          ),
          pw.SizedBox(height: 20),

          //================================================
          // FINAL ESP32 STATUS
          //================================================
          pw.Header(level: 1, text: 'Run Status'),
          pw.TableHelper.fromTextArray(
            headers: const ['Parameter', 'Value'],
            data: [
              [
                'Current Temperature',
                finalStatus == null
                    ? '--'
                    : '${finalStatus.temperature.toStringAsFixed(2)} °C',
              ],
              [
                'Target Temperature',
                finalStatus == null
                    ? '--'
                    : '${finalStatus.target.toStringAsFixed(2)} °C',
              ],
              [
                'Current Stage',
                finalStatus == null ? '--' : finalStatus.stageName,
              ],
              [
                'Phase',
                finalStatus == null ? '--' : finalStatus.phase,
              ],
              [
                'Cycle',
                finalStatus == null
                    ? '--'
                    : '${finalStatus.cycle}/${finalStatus.totalCycles}',
              ],
              [
                'Hold Remaining',
                finalStatus == null
                    ? '--'
                    : _formatSeconds(finalStatus.holdRemaining),
              ],
              [
                'Heater',
                finalStatus == null
                    ? '--'
                    : finalStatus.heater
                    ? 'ON'
                    : 'OFF',
              ],
              [
                'Cooling',
                finalStatus == null
                    ? '--'
                    : finalStatus.cooling
                    ? 'ON'
                    : 'OFF',
              ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blue700,
            ),
            cellPadding: const pw.EdgeInsets.all(6),
            border: pw.TableBorder.all(color: PdfColors.grey300),
          ),
          pw.SizedBox(height: 25),

          //================================================
          // PROCESSED TEMPERATURE PROFILE
          //================================================
          pw.Header(level: 1, text: 'Temperature Profile'),
          pw.Text(
            'Initial denaturation, averaged cycling profile across N cycles, '
                'final extension, and actual cooling to the final hold.',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: profile.actual.isEmpty
                ? pw.SizedBox(
              height: 220,
              child: pw.Center(
                child: pw.Text('No temperature data recorded.'),
              ),
            )
                : pw.SvgImage(
              svg: _buildGraphSvg(
                profile.actual,
                profile.target,
              ),
              width: 500,
              height: 270,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'The cycling section is aligned stage-by-stage and averaged across '
                '${profile.cyclesUsed} recorded cycle(s). Raw ESP32 readings remain '
                'separate from the display-only HOLD smoothing used by the live UI.',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 25),

          //================================================
          // RAW DATA NOTE
          //================================================
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              'Report note: PCR execution, stage transitions, cycle timing, '
                  'heating and cooling are controlled by the ESP32. Flutter only '
                  'records ESP32 status/temperature data and performs report '
                  'post-processing. The averaged graph does not alter PCR control '
                  'or timing on the ESP32.',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey800,
              ),
            ),
          ),
        ],
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  //==================================================
  // BUILD PROCESSED PROFILE
  //
  // Output order:
  //   1. Initial denaturation
  //   2. Average of N cycles
  //   3. Final extension
  //   4. Cooling / final hold
  //==================================================

  static _ProcessedProfile _buildProcessedProfile({
    required PCRProgram program,
    required List<PCRTemperatureSample> samples,
  }) {
    if (samples.isEmpty) {
      return const _ProcessedProfile(
        actual: [],
        target: [],
        cyclesUsed: 0,
      );
    }

    final ordered = List<PCRTemperatureSample>.from(samples)
      ..sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));

    final firstCycleIndex = ordered.indexWhere(
          (sample) => sample.cycle >= 1 && sample.cycle <= program.cycles,
    );

    final initialEnd = firstCycleIndex < 0
        ? ordered.length
        : firstCycleIndex;

    final initialSamples = ordered.sublist(0, initialEnd);

    final cyclingSamples = ordered.where((sample) {
      return sample.cycle >= 1 && sample.cycle <= program.cycles;
    }).toList();

    final finalExtensionPredicate = (PCRTemperatureSample sample) {
      final name = sample.stageName.toLowerCase();
      return name.contains('final') && name.contains('extension');
    };

    int finalStartIndex = ordered.indexWhere(finalExtensionPredicate);

    // Fallback for firmware versions that may not expose the exact
    // "Final Extension" stage name: look after the last cycling sample
    // for a sample whose target is the programmed final temperature.
    if (finalStartIndex < 0) {
      final int lastCycleIndex = _lastIndexWhere(
        ordered,
            (sample) =>
        sample.cycle >= 1 && sample.cycle <= program.cycles,
      );

      for (int i = math.max(0, lastCycleIndex + 1);
      i < ordered.length;
      i++) {
        if ((ordered[i].target - program.finalTemp).abs() <= 1.5) {
          finalStartIndex = i;
          break;
        }
      }
    }

    if (finalStartIndex < 0 && cyclingSamples.isNotEmpty) {
      finalStartIndex = ordered.indexOf(cyclingSamples.last) + 1;
      if (finalStartIndex >= ordered.length) {
        finalStartIndex = -1;
      }
    }

    final finalSamples = <PCRTemperatureSample>[];
    final coolingSamples = <PCRTemperatureSample>[];

    if (finalStartIndex >= 0) {
      bool inFinal = false;
      for (int i = finalStartIndex; i < ordered.length; i++) {
        final finalSample = ordered[i];
        final bool isFinal = finalExtensionPredicate(finalSample) ||
            (!inFinal &&
                (finalSample.target - program.finalTemp).abs() <= 1.5 &&
                finalSample.cycle >= program.cycles);

        if (isFinal || !inFinal) {
          if (isFinal) {
            inFinal = true;
            finalSamples.add(finalSample);
            continue;
          }
        }

        if (inFinal) {
          coolingSamples.add(finalSample);
        }
      }
    }

    // If the final stage was not detected, retain everything after the
    // cycling section as the post-cycle segment instead of dropping data.
    if (finalStartIndex < 0) {
      final int lastCycleIndex = _lastIndexWhere(
        ordered,
            (sample) =>
        sample.cycle >= 1 && sample.cycle <= program.cycles,
      );

      if (lastCycleIndex >= 0 && lastCycleIndex + 1 < ordered.length) {
        coolingSamples.addAll(ordered.sublist(lastCycleIndex + 1));
      }
    }

    final actual = <FlSpot>[];
    final target = <FlSpot>[];

    double x = 0;

    //================================================
    // INITIAL DENATURATION - ACTUAL
    //================================================

    x = _appendActualSegment(
      actual: actual,
      target: target,
      samples: initialSamples,
      xStart: x,
      targetFallback: program.initialTemp,
    );

    //================================================
    // N-CYCLE AVERAGE
    //================================================

    final cycleProfile = _buildAverageCycle(
      program: program,
      cyclingSamples: cyclingSamples,
    );

    if (cycleProfile.actual.isNotEmpty) {
      for (int i = 0; i < cycleProfile.actual.length; i++) {
        actual.add(
          FlSpot(
            x + cycleProfile.actual[i].x,
            cycleProfile.actual[i].y,
          ),
        );
        target.add(
          FlSpot(
            x + cycleProfile.target[i].x,
            cycleProfile.target[i].y,
          ),
        );
      }

      x += cycleProfile.duration;
    }

    //================================================
    // FINAL EXTENSION - ACTUAL
    //================================================

    x = _appendActualSegment(
      actual: actual,
      target: target,
      samples: finalSamples,
      xStart: x,
      targetFallback: program.finalTemp,
    );

    //================================================
    // COOLING / FINAL HOLD - ACTUAL
    //================================================

    _appendActualSegment(
      actual: actual,
      target: target,
      samples: coolingSamples,
      xStart: x,
      targetFallback: coolingSamples.isNotEmpty
          ? coolingSamples.first.target
          : 4.0,
    );

    // If the run contained no cycle metadata, fall back to the raw profile
    // instead of producing an incomplete report.
    if (actual.length < 2) {
      return _ProcessedProfile(
        actual: ordered
            .map(
              (sample) => FlSpot(
            sample.elapsedSeconds,
            sample.temperature,
          ),
        )
            .toList(),
        target: ordered
            .map(
              (sample) => FlSpot(
            sample.elapsedSeconds,
            sample.target,
          ),
        )
            .toList(),
        cyclesUsed: 0,
      );
    }

    return _ProcessedProfile(
      actual: actual,
      target: target,
      cyclesUsed: cycleProfile.cyclesUsed,
    );
  }

  //==================================================
  // AVERAGE THE CYCLING SECTION
  //
  // Each stage is normalized independently, so a slightly
  // faster/slower ramp in one cycle does not shift the next
  // stage before averaging.
  //==================================================

  static _CycleProfile _buildAverageCycle({
    required PCRProgram program,
    required List<PCRTemperatureSample> cyclingSamples,
  }) {
    if (cyclingSamples.isEmpty || program.stages.isEmpty) {
      return const _CycleProfile(
        actual: [],
        target: [],
        duration: 0,
        cyclesUsed: 0,
      );
    }

    final cycles = <int>{
      for (final sample in cyclingSamples) sample.cycle,
    }.where((cycle) => cycle >= 1 && cycle <= program.cycles).toList()
      ..sort();

    if (cycles.isEmpty) {
      return const _CycleProfile(
        actual: [],
        target: [],
        duration: 0,
        cyclesUsed: 0,
      );
    }

    const pointsPerStage = 16;
    final actual = <FlSpot>[];
    final target = <FlSpot>[];
    double xOffset = 0;
    int stagesContributing = 0;

    for (int stageIndex = 0;
    stageIndex < program.stages.length;
    stageIndex++) {
      final stage = program.stages[stageIndex];
      final perCycle = <int, List<PCRTemperatureSample>>{};

      for (final cycle in cycles) {
        final stageSamples = cyclingSamples.where((sample) {
          return sample.cycle == cycle &&
              _stageMatches(sample, stage, stageIndex, program.stages);
        }).toList();

        if (stageSamples.isNotEmpty) {
          perCycle[cycle] = stageSamples
            ..sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));
        }
      }

      if (perCycle.isEmpty) {
        continue;
      }

      stagesContributing++;

      final representativeDuration = _averageStageDuration(
        perCycle.values.toList(),
        fallback: stage.holdTime.toDouble(),
      );

      for (int pointIndex = 0; pointIndex < pointsPerStage; pointIndex++) {
        final normalized = pointsPerStage == 1
            ? 0.0
            : pointIndex / (pointsPerStage - 1);

        double actualSum = 0;
        double targetSum = 0;
        int count = 0;

        for (final stageSamples in perCycle.values) {
          final value = _interpolateStage(
            stageSamples,
            normalized,
            useTarget: false,
            fallback: stage.temperature,
          );
          final targetValue = _interpolateStage(
            stageSamples,
            normalized,
            useTarget: true,
            fallback: stage.temperature,
          );

          actualSum += value;
          targetSum += targetValue;
          count++;
        }

        if (count == 0) {
          continue;
        }

        final localX = xOffset + normalized * representativeDuration;

        // Avoid duplicating the exact boundary point between adjacent stages.
        if (actual.isNotEmpty && pointIndex == 0) {
          continue;
        }

        actual.add(
          FlSpot(
            localX,
            actualSum / count,
          ),
        );

        target.add(
          FlSpot(
            localX,
            targetSum / count,
          ),
        );
      }

      xOffset += representativeDuration;
    }

    return _CycleProfile(
      actual: actual,
      target: target,
      duration: xOffset,
      cyclesUsed: stagesContributing == 0 ? 0 : cycles.length,
    );
  }

  static bool _stageMatches(
      PCRTemperatureSample sample,
      PCRStage stage,
      int stageIndex,
      List<PCRStage> stages,
      ) {
    final sampleName = sample.stageName.trim().toLowerCase();
    final expectedName = stage.stageName.trim().toLowerCase();

    if (sampleName.isNotEmpty && sampleName != 'idle') {
      if (sampleName == expectedName ||
          sampleName.contains(expectedName) ||
          expectedName.contains(sampleName)) {
        return true;
      }
    }

    // Fallback to the programmed stage temperature when the ESP32 does not
    // expose the stage name exactly as stored in the Flutter program.
    if ((sample.target - stage.temperature).abs() <= 1.5) {
      return true;
    }

    // Last fallback: preserve ordering when several stages share a similar
    // target temperature by checking the sample's position in the stage list.
    final name = sample.stageName.toLowerCase();
    if (name.contains('denaturation') && stageIndex == 0) return true;
    if (name.contains('anneal') && expectedName.contains('anneal')) return true;
    if (name.contains('extension') && !name.contains('final') &&
        expectedName.contains('extension')) {
      return true;
    }

    return false;
  }

  static double _averageStageDuration(
      List<List<PCRTemperatureSample>> stageCycles, {
        required double fallback,
      }) {
    final durations = <double>[];

    for (final samples in stageCycles) {
      if (samples.length >= 2) {
        final duration =
            samples.last.elapsedSeconds - samples.first.elapsedSeconds;
        if (duration > 0) {
          durations.add(duration);
        }
      }
    }

    if (durations.isEmpty) {
      return math.max(1.0, fallback);
    }

    return durations.reduce((a, b) => a + b) / durations.length;
  }

  static double _interpolateStage(
      List<PCRTemperatureSample> samples,
      double normalized,
      {required bool useTarget, required double fallback}
      ) {
    if (samples.isEmpty) return fallback;
    if (samples.length == 1) {
      return useTarget ? samples.first.target : samples.first.temperature;
    }

    final first = samples.first.elapsedSeconds;
    final last = samples.last.elapsedSeconds;
    final span = last - first;

    if (span <= 0) {
      return useTarget ? samples.last.target : samples.last.temperature;
    }

    final wanted = first + normalized.clamp(0.0, 1.0) * span;

    for (int i = 1; i < samples.length; i++) {
      final left = samples[i - 1];
      final right = samples[i];

      if (wanted <= right.elapsedSeconds) {
        final dx = right.elapsedSeconds - left.elapsedSeconds;
        final fraction = dx <= 0
            ? 0.0
            : (wanted - left.elapsedSeconds) / dx;

        final leftValue = useTarget ? left.target : left.temperature;
        final rightValue = useTarget ? right.target : right.temperature;

        return leftValue +
            (rightValue - leftValue) * fraction.clamp(0.0, 1.0);
      }
    }

    return useTarget ? samples.last.target : samples.last.temperature;
  }

  //==================================================
  // APPEND AN ACTUAL SEGMENT
  //==================================================

  static double _appendActualSegment({
    required List<FlSpot> actual,
    required List<FlSpot> target,
    required List<PCRTemperatureSample> samples,
    required double xStart,
    required double targetFallback,
  }) {
    if (samples.isEmpty) return xStart;

    final ordered = List<PCRTemperatureSample>.from(samples)
      ..sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));

    final baseTime = ordered.first.elapsedSeconds;

    for (int i = 0; i < ordered.length; i++) {
      final sample = ordered[i];
      final localX = sample.elapsedSeconds - baseTime;
      final x = xStart + localX;

      if (actual.isNotEmpty && x <= actual.last.x) {
        continue;
      }

      actual.add(FlSpot(x, sample.temperature));
      target.add(
        FlSpot(
          x,
          sample.target.isFinite ? sample.target : targetFallback,
        ),
      );
    }

    if (ordered.length == 1) {
      return xStart + 1.0;
    }

    return xStart +
        math.max(0.001, ordered.last.elapsedSeconds - baseTime);
  }

  static int _lastIndexWhere(
      List<PCRTemperatureSample> samples,
      bool Function(PCRTemperatureSample) test,
      ) {
    for (int i = samples.length - 1; i >= 0; i--) {
      if (test(samples[i])) return i;
    }
    return -1;
  }

  //==================================================
  // DATA TABLE
  //==================================================

  static pw.Widget _buildDataTable(
      List<FlSpot> actual,
      List<FlSpot> target,
      ) {
    if (actual.isEmpty) {
      return pw.Text('No processed temperature samples available.');
    }

    final rowCount = math.min(actual.length, target.length);
    final step = rowCount <= 60 ? 1 : (rowCount / 60).ceil();
    final data = <List<String>>[];

    for (int i = 0; i < rowCount; i += step) {
      data.add([
        '${actual[i].x.toStringAsFixed(1)} s',
        '${actual[i].y.toStringAsFixed(2)} °C',
        '${target[i].y.toStringAsFixed(2)} °C',
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: const ['Time', 'Actual', 'Target'],
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.blue700,
      ),
      cellPadding: const pw.EdgeInsets.all(5),
      border: pw.TableBorder.all(color: PdfColors.grey300),
    );
  }

  //==================================================
  // BUILD SVG GRAPH
  //==================================================

  static String _buildGraphSvg(
      List<FlSpot> actual,
      List<FlSpot> target,
      ) {
    const double width = 760;
    const double height = 360;
    const double left = 60;
    const double right = 20;
    const double top = 25;
    const double bottom = 45;

    final plotWidth = width - left - right;
    final plotHeight = height - top - bottom;
    final count = math.min(actual.length, target.length);

    if (count <= 0) {
      return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $width $height">
  <text x="380" y="180" text-anchor="middle" font-size="18">No temperature data</text>
</svg>''';
    }

    final step = count <= 300 ? 1 : (count / 300).ceil();
    final indices = <int>[];
    for (int i = 0; i < count; i += step) {
      indices.add(i);
    }
    if (indices.last != count - 1) indices.add(count - 1);

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final i in indices) {
      minY = math.min(minY, actual[i].y);
      maxY = math.max(maxY, actual[i].y);
      minY = math.min(minY, target[i].y);
      maxY = math.max(maxY, target[i].y);
    }

    if (!minY.isFinite || !maxY.isFinite) {
      minY = 0;
      maxY = 100;
    }

    if ((maxY - minY) < 10) {
      final center = (maxY + minY) / 2;
      minY = center - 5;
      maxY = center + 5;
    }

    final margin = (maxY - minY) * 0.08;
    minY -= margin;
    maxY += margin;
    if (minY < 0) minY = 0;

    final firstX = actual.first.x;
    final lastX = actual[count - 1].x;
    final xRange = (lastX - firstX) == 0 ? 1.0 : lastX - firstX;

    String pointToSvg(FlSpot point) {
      final x = left +
          ((point.x - firstX) / xRange) * plotWidth;
      final y = top +
          (1 - ((point.y - minY) / (maxY - minY))) * plotHeight;
      return '${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}';
    }

    final actualPoints = indices.map((i) => pointToSvg(actual[i])).join(' ');
    final targetPoints = indices.map((i) => pointToSvg(target[i])).join(' ');

    final grid = StringBuffer();
    const gridLines = 5;

    for (int i = 0; i <= gridLines; i++) {
      final y = top + (plotHeight / gridLines) * i;
      final value = maxY - ((maxY - minY) / gridLines) * i;
      grid.writeln('''
<line x1="$left" y1="${y.toStringAsFixed(1)}"
      x2="${(width - right).toStringAsFixed(1)}"
      y2="${y.toStringAsFixed(1)}"
      stroke="#d0d7de" stroke-width="1" stroke-dasharray="5,5"/>
<text x="${left - 8}" y="${(y + 4).toStringAsFixed(1)}"
      text-anchor="end" font-size="12" fill="#555">${value.toStringAsFixed(0)}</text>
''');
    }

    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $width $height">
  <rect x="0" y="0" width="$width" height="$height" fill="white"/>

  <text x="${width / 2}" y="18" text-anchor="middle"
        font-size="15" font-weight="bold" fill="#222">
    PCR Temperature Profile - Averaged Cycling Section
  </text>

  ${grid.toString()}

  <line x1="$left" y1="$top" x2="$left" y2="${height - bottom}"
        stroke="#444" stroke-width="1.5"/>
  <line x1="$left" y1="${height - bottom}"
        x2="${width - right}" y2="${height - bottom}"
        stroke="#444" stroke-width="1.5"/>

  <polyline points="$targetPoints" fill="none"
            stroke="#1976D2" stroke-width="2.5"
            stroke-dasharray="8,5"/>
  <polyline points="$actualPoints" fill="none"
            stroke="#F44336" stroke-width="3"/>

  <text x="${width - 175}" y="38" font-size="12" fill="#F44336">Actual</text>
  <text x="${width - 175}" y="56" font-size="12" fill="#1976D2">Target</text>

  <text x="${width / 2}" y="${height - 8}" text-anchor="middle"
        font-size="12" fill="#555">Representative time (seconds)</text>
</svg>
''';
  }

  //==================================================
  // FILE NAME
  //==================================================

  static String buildFileName(
      String programName,
      DateTime dateTime,
      ) {
    String cleanName = programName.trim();
    if (cleanName.isEmpty) cleanName = 'PCR_Run';

    cleanName = cleanName.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]+'),
      '_',
    );

    final timestamp =
        '${dateTime.year}'
        '${dateTime.month.toString().padLeft(2, '0')}'
        '${dateTime.day.toString().padLeft(2, '0')}_'
        '${dateTime.hour.toString().padLeft(2, '0')}'
        '${dateTime.minute.toString().padLeft(2, '0')}'
        '${dateTime.second.toString().padLeft(2, '0')}';

    return 'PCR_Report_${cleanName}_$timestamp.pdf';
  }

  //==================================================
  // FORMAT DATE/TIME
  //==================================================

  static String _formatDateTime(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
  }

  //==================================================
  // FORMAT SECONDS
  //==================================================

  static String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (minutes > 0) {
      return '${minutes} min ${remainingSeconds} sec';
    }

    return '${remainingSeconds} sec';
  }

  //==================================================
  // FORMAT DURATION
  //==================================================

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours} h ${minutes} min ${seconds} sec';
    }

    if (minutes > 0) {
      return '${minutes} min ${seconds} sec';
    }

    return '${seconds} sec';
  }
}

//====================================================
// INTERNAL REPORT DATA TYPES
//====================================================

class _ProcessedProfile {
  final List<FlSpot> actual;
  final List<FlSpot> target;
  final int cyclesUsed;

  const _ProcessedProfile({
    required this.actual,
    required this.target,
    required this.cyclesUsed,
  });
}

class _CycleProfile {
  final List<FlSpot> actual;
  final List<FlSpot> target;
  final double duration;
  final int cyclesUsed;

  const _CycleProfile({
    required this.actual,
    required this.target,
    required this.duration,
    required this.cyclesUsed,
  });
}
