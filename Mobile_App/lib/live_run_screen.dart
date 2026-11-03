import 'dart:async';

import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

import '../models/live_status.dart';
import '../models/pcr_program.dart';
import '../models/pcr_temperature_sample.dart';
import '../services/esp32_service.dart';
import '../services/pcr_report_service.dart';

class LiveRunScreen extends StatefulWidget {

  final PCRProgram program;

  const LiveRunScreen({
    super.key,
    required this.program,
  });

  @override
  State<LiveRunScreen> createState() =>
      _LiveRunScreenState();
}

class _LiveRunScreenState
    extends State<LiveRunScreen> {

  //==================================================
  // ESP32 STATUS
  //==================================================

  LiveStatus? status;

  bool connected = false;

  bool loading = true;

  bool reportBusy = false;

  String connectionText =
      "Connecting...";

  DateTime? lastSuccessfulStatus;

  Timer? refreshTimer;

  bool requestInProgress = false;
  bool recordingRun = false;

  //==================================================
  // PCR RUN TIME
  //==================================================

  late final DateTime runStartedAt;
  DateTime? esp32RunStartedAt;

  //==================================================
  // RAW PCR SAMPLES FOR REPORTING
  //
  // These are the real temperature readings received by the app.
  // They are recorded every five seconds and feed both CSV options.
  //==================================================

  final List<PCRTemperatureSample>
  reportTemperatureSamples = [];

  // Samples are recorded locally from successful /status responses.
  // No historical /telemetry requests are made.

  //==================================================
  // INIT
  //==================================================

  @override
  void initState() {

    super.initState();

    runStartedAt =
        DateTime.now();

    // Get first ESP32 status immediately.
    _refreshStatus();

    // ESP32 status polling only; this is NOT PCR timing.
    // Requests are serialized by requestInProgress. If one request times out,
    // the periodic timer continues and the next tick retries automatically.
    refreshTimer =
        Timer.periodic(
          const Duration(
            seconds: 1,
          ),
              (_) {
            _refreshStatus();
          },
        );
  }

  //==================================================
  // DISPOSE
  //==================================================

  @override
  void dispose() {

    refreshTimer?.cancel();

    super.dispose();
  }

  //==================================================
  // REFRESH STATUS + RECORD RECEIVED READINGS LOCALLY
  //
  // /status is already polled once per second for the live UI.
  // Record the temperature values from those same responses rather
  // than issuing additional /telemetry requests to the ESP32.
  // This keeps graph/report generation on the phone and avoids extra
  // Wi-Fi traffic. Readings missed during a disconnect cannot be
  // reconstructed by this app-only approach.
  //==================================================

  Future<void> _refreshStatus() async {
    if (requestInProgress) return;
    requestInProgress = true;

    try {
      final LiveStatus? result = await ESP32Service.getStatus();
      if (!mounted) return;

      if (result == null) {
        setState(() {
          loading = false;
          connected = false;
          connectionText = "Connection Lost — Reconnecting...";
        });
        return;
      }

      final now = DateTime.now();
      if (result.running) {
        // The first successful running status defines the local run's
        // time origin. This also works if this screen opens mid-run.
        if (!recordingRun) {
          recordingRun = true;
          esp32RunStartedAt = now;
          reportTemperatureSamples.clear();
        }

        final elapsed = now.difference(esp32RunStartedAt!).inMilliseconds / 1000.0;
        final shouldRecord = reportTemperatureSamples.isEmpty ||
            elapsed - reportTemperatureSamples.last.elapsedSeconds >= 5.0;
        if (shouldRecord) {
          reportTemperatureSamples.add(_sampleFromStatus(result, elapsed));
        }
      } else if (recordingRun) {
        // Capture the final status once when the run stops/completes, even if
        // fewer than five seconds have passed since the previous sample.
        final elapsed = now.difference(esp32RunStartedAt!).inMilliseconds / 1000.0;
        if (reportTemperatureSamples.isEmpty ||
            elapsed > reportTemperatureSamples.last.elapsedSeconds) {
          reportTemperatureSamples.add(_sampleFromStatus(result, elapsed));
        }
        recordingRun = false;
      }

      setState(() {
        loading = false;
        connected = true;
        connectionText = "ESP32 Connected";
        lastSuccessfulStatus = now;
        status = result;
      });
    } catch (e, s) {
      debugPrint("LIVE SCREEN STATUS ERROR: $e");
      debugPrint(s.toString());
      if (!mounted) return;
      setState(() {
        loading = false;
        connected = false;
        connectionText = "Connection Lost — Reconnecting...";
      });
    } finally {
      requestInProgress = false;
    }
  }

  PCRTemperatureSample _sampleFromStatus(LiveStatus value, double elapsed) {
    return PCRTemperatureSample(
      elapsedSeconds: elapsed,
      temperature: value.temperature,
      target: value.target,
      cycle: value.cycle,
      stageName: value.stageName,
      phase: value.phase,
      holdRemainingMs: value.holdRemainingMs,
    );
  }

  //==================================================
  // HOLD DISPLAY
  //
  // IMPORTANT:
  //
  // NO FLUTTER COUNTDOWN.
  //
  // The value comes directly from ESP32.
  //==================================================

  String get holdDisplay {

    if (status == null) {
      return "--";
    }

    final totalSeconds =
        status!.holdRemaining;

    final minutes =
        totalSeconds ~/ 60;

    final seconds =
        totalSeconds % 60;

    return
      "${minutes.toString().padLeft(2, '0')}:"
          "${seconds.toString().padLeft(2, '0')}";
  }
  //==================================================
// DISPLAY TEMPERATURE
//
// Matches the ESP32 LCD presentation logic.
//
// During HOLD:
// If actual temperature is within ±1°C of target,
// display the target temperature instead of the
// small sensor fluctuations.
//
// IMPORTANT:
// This changes ONLY what Flutter displays.
// The actual ESP32 temperature remains unchanged.
//==================================================

  double get displayTemperature {
    if (status == null) {
      return 0.0;
    }

    final actual = status!.temperature;
    final target = status!.target;

    final bool isHolding =
        status!.phase.toLowerCase() == "holding";

    final bool isWithinHoldBand =
        (actual - target).abs() <= 1.0;

    if (isHolding && isWithinHoldBand) {
      return target;
    }

    return actual;
  }
  //==================================================
  // REPORT OPTIONS: RAW CSV OR CSV + GRAPH PDF
  //==================================================

  Future<void> _showReportOptions() async {
    if (reportBusy) return;
    if (reportTemperatureSamples.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No temperature data has been recorded yet. Start a PCR run first.')),
      );
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('PCR Report Options', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.table_view),
                title: const Text('Option 1 — Raw CSV'),
                subtitle: const Text('Timestamped temperature and PCR status readings every 5 seconds.'),
                onTap: () => Navigator.pop(sheetContext, 'raw'),
              ),
              ListTile(
                leading: const Icon(Icons.insert_chart_outlined),
                title: const Text('Option 2 — CSV + Graph Report'),
                subtitle: const Text('Export the same CSV data plus a PDF graph/report plotted from those readings.'),
                onTap: () => Navigator.pop(sheetContext, 'graph'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;
    await _exportReport(choice);
  }

  String _csvEscape(Object? value) {
    final text = (value ?? '').toString();
    if (text.contains(',') || text.contains('"') || text.contains('\n') || text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  String _buildRawCsv(List<PCRTemperatureSample> samples, DateTime startedAt) {
    final rows = <List<Object?>>[
      ['Time', 'Time_Elasped(Sec)', 'Temperature', 'target_c', 'Cycle', 'Stage', 'Phase'],
    ];
    for (final sample in samples) {
      final timestamp = startedAt
          .add(Duration(milliseconds: (sample.elapsedSeconds * 1000).round()))
          .toLocal();
      final timeText =
          '${timestamp.hour.toString().padLeft(2, '0')}:'
          '${timestamp.minute.toString().padLeft(2, '0')}:'
          '${timestamp.second.toString().padLeft(2, '0')}';
      rows.add([
        timeText,
        sample.elapsedSeconds.toStringAsFixed(1),
        sample.temperature.toStringAsFixed(3),
        sample.target.toStringAsFixed(3),
        sample.cycle,
        sample.stageName,
        sample.phase,
      ]);
    }
    return '\uFEFF${rows.map((row) => row.map(_csvEscape).join(',')).join('\r\n')}\r\n';
  }

  Future<void> _exportReport(String choice) async {
    if (reportBusy) return;
    final samples = List<PCRTemperatureSample>.unmodifiable(reportTemperatureSamples);
    if (samples.isEmpty) return;
    final startedAt = esp32RunStartedAt ?? runStartedAt;
    final csv = _buildRawCsv(samples, startedAt);
    final timestamp = DateTime.now();
    final baseName = PCRReportService.buildFileName(widget.program.name, timestamp)
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');

    setState(() => reportBusy = true);
    try {
      final files = <XFile>[
        XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: '${baseName}_raw_data.csv'),
      ];

      if (choice == 'graph') {
        final pdfBytes = await PCRReportService.generateReport(
          program: widget.program,
          reportTemperatureSamples: samples,
          runStartedAt: startedAt,
          generatedAt: timestamp,
          finalStatus: status,
        );
        files.add(XFile.fromData(
          pdfBytes,
          mimeType: 'application/pdf',
          name: '${baseName}_graph_report.pdf',
        ));
      }

      await SharePlus.instance.share(ShareParams(
        files: files,
        subject: choice == 'raw' ? 'PCR raw data CSV' : 'PCR CSV and graph report',
        text: choice == 'raw'
            ? 'Raw PCR temperature data (one sample every 5 seconds).'
            : 'PCR raw CSV data and PDF graph report generated from the same readings.',
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(choice == 'raw'
            ? 'Raw CSV is ready to save or share.'
            : 'CSV and graph report are ready to save or share.'),
      ));
    } catch (e, stack) {
      debugPrint('PCR EXPORT ERROR: $e');
      debugPrint(stack.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export PCR report: $e')),
      );
    } finally {
      if (mounted) setState(() => reportBusy = false);
    }
  }

  //==================================================
  // INFO CARD
  //==================================================

  Widget infoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {

    return Card(

      elevation: 3,

      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
      ),

      child: Padding(

        padding:
        const EdgeInsets.all(18),

        child: Row(

          children: [

            CircleAvatar(

              radius: 26,

              backgroundColor:
              color.withOpacity(
                0.15,
              ),

              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),

            const SizedBox(
              width: 18,
            ),

            Expanded(

              child: Column(

                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  Text(
                    title,

                    style:
                    const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    value,

                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //==================================================
  // CONNECTION CARD
  //==================================================

  Widget connectionCard() {

    return Card(

      color: connected
          ? Colors.green.shade100
          : Colors.orange.shade100,

      child: ListTile(

        leading: Icon(

          connected
              ? Icons.wifi
              : Icons.wifi_off,

          color: connected
              ? Colors.green
              : Colors.orange,
        ),

        title: Text(

          connectionText,

          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),

        subtitle: Text(

          connected
              ? "ESP32 is controlling the PCR; graph and report use readings received by this app."
              : "PCR continues on the ESP32 while Flutter reconnects. Readings missed during disconnection may not appear in the report.",
        ),
      ),
    );
  }

  //==================================================
  // THERMAL STATUS
  //==================================================

  Widget thermalStatusCard() {

    final heaterOn =
        status?.heater == true;

    final coolingOn =
        status?.cooling == true;

    final running =
        status?.running == true;

    return Card(

      elevation: 3,

      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
      ),

      child: Padding(

        padding:
        const EdgeInsets.all(18),

        child: Row(

          children: [

            //==========================================
            // HEATER
            //==========================================

            Expanded(

              child: Column(

                children: [

                  Icon(

                    Icons
                        .local_fire_department,

                    size: 40,

                    color: heaterOn
                        ? Colors.red
                        : Colors.grey,
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    "Heater",

                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  Text(
                    heaterOn
                        ? "ON"
                        : "OFF",
                  ),
                ],
              ),
            ),

            //==========================================
            // COOLING
            //==========================================

            Expanded(

              child: Column(

                children: [

                  Icon(

                    Icons.ac_unit,

                    size: 40,

                    color: coolingOn
                        ? Colors.blue
                        : Colors.grey,
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    "Cooling",

                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  Text(
                    coolingOn
                        ? "ON"
                        : "OFF",
                  ),
                ],
              ),
            ),

            //==========================================
            // PCR
            //==========================================

            Expanded(

              child: Column(

                children: [

                  Icon(

                    Icons
                        .play_circle_fill,

                    size: 40,

                    color: running
                        ? Colors.green
                        : Colors.grey,
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    "PCR",

                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  Text(
                    running
                        ? "Running"
                        : "Idle",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  //==================================================
  // REPORT BUTTON
  //==================================================

  Widget controlButton({
    required String label,
    required IconData icon,
    required Color color,
    required Future<void>
    Function() onPressed,
  }) {

    return Expanded(

      child: ElevatedButton.icon(

        style:
        ElevatedButton.styleFrom(

          backgroundColor:
          color,

          foregroundColor:
          Colors.white,

          padding:
          const EdgeInsets.symmetric(
            vertical: 14,
          ),
        ),

        onPressed: () async {

          await onPressed();
        },

        icon:
        Icon(icon),

        label:
        Text(label),
      ),
    );
  }

  Widget reportButton() {

    return SizedBox(

      width:
      double.infinity,

      child:
      ElevatedButton.icon(

        style:
        ElevatedButton.styleFrom(

          backgroundColor:
          Colors.blue.shade700,

          foregroundColor:
          Colors.white,

          padding:
          const EdgeInsets.symmetric(
            vertical: 16,
          ),

          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(12),
          ),
        ),

        onPressed:
        reportBusy
            ? null
            : _showReportOptions,

        icon:

        reportBusy

            ? const SizedBox(
          width: 20,
          height: 20,

          child:
          CircularProgressIndicator(
            strokeWidth: 2,
            color:
            Colors.white,
          ),
        )

            : const Icon(
          Icons
              .picture_as_pdf,
        ),

        label:

        Text(
          reportBusy
              ? "Preparing Report..."
              : "Reports / Export Data",
        ),
      ),
    );
  }

  //==================================================
  // BUILD
  //==================================================

  @override
  Widget build(
      BuildContext context,
      ) {

    return Scaffold(

      appBar:
      AppBar(

        title:
        const Text(
          "Live PCR Run",
        ),

        centerTitle:
        true,

        actions: [

          IconButton(

            tooltip:
            "Refresh",

            icon:
            const Icon(
              Icons.refresh,
            ),

            onPressed:
            _refreshStatus,
          ),

          IconButton(

            tooltip:
            "Download PCR Report",

            icon:
            reportBusy

                ? const SizedBox(
              width: 20,
              height: 20,

              child:
              CircularProgressIndicator(
                strokeWidth:
                2,
              ),
            )

                : const Icon(Icons.file_download),

            onPressed:
            reportBusy
                ? null
                : _showReportOptions,
          ),
        ],
      ),

      body:

      loading

          ? const Center(

        child:
        CircularProgressIndicator(),
      )

          : ListView(

        padding:
        const EdgeInsets.all(
          16,
        ),

        children: [

          //================================
          // CONNECTION
          //================================

          connectionCard(),

          const SizedBox(
            height: 18,
          ),

          //================================
          // TEMPERATURE
          //================================

          infoCard(
            icon:
            Icons.thermostat,

            title:
            "Current Temperature",

            value:

            status == null
                ? "--"
                : "${displayTemperature.toStringAsFixed(1)} °C",

            color:
            Colors.red,
          ),

          //================================
          // TARGET
          //================================

          infoCard(

            icon:
            Icons.flag,

            title:
            "Target Temperature",

            value:

            status == null

                ? "--"

                : "${status!.target.toStringAsFixed(2)} °C",

            color:
            Colors.orange,
          ),

          //================================
          // STAGE
          //================================

          infoCard(

            icon:
            Icons.science,

            title:
            "Current PCR Stage",

            value:

            status == null

                ? "--"

                : "${status!.stageName}\n${status!.phase}",

            color:
            Colors.blue,
          ),

          //================================
          // CYCLE
          //================================

          infoCard(

            icon:
            Icons.repeat,

            title:
            "Current Cycle",

            value:

            status == null

                ? "--"

                : "${status!.cycle}/${status!.totalCycles}",

            color:
            Colors.green,
          ),

          //================================
          // HOLD
          //================================

          infoCard(

            icon:
            Icons.timer,

            title:

            connected

                ? "Hold Remaining"

                : "Hold Remaining (Last Sync)",

            value:
            holdDisplay,

            color:
            Colors.orange,
          ),

          const SizedBox(
            height: 18,
          ),

          //================================
          // THERMAL STATUS
          //================================

          thermalStatusCard(),

          const SizedBox(
            height: 25,
          ),

          //================================
          // REPORT OPTIONS
          //================================

          //================================
          // REPORT BUTTON
          //================================

          reportButton(),

          const SizedBox(
            height: 30,
          ),

          //================================
          // PCR CONTROLS
          //================================

          Row(

            children: [

              controlButton(

                label:
                "Pause",

                icon:
                Icons.pause,

                color:
                Colors.orange,

                onPressed:
                    () async {

                  await ESP32Service
                      .pausePCR();

                  await _refreshStatus();
                },
              ),

              const SizedBox(
                width: 10,
              ),

              controlButton(

                label:
                "Resume",

                icon:
                Icons.play_arrow,

                color:
                Colors.green,

                onPressed:
                    () async {

                  await ESP32Service
                      .resumePCR();

                  await _refreshStatus();
                },
              ),

              const SizedBox(
                width: 10,
              ),

              controlButton(

                label:
                "Stop",

                icon:
                Icons.stop,

                color:
                Colors.red,

                onPressed:
                    () async {

                  // Stop PCR on the ESP32.
                  // Do NOT leave the Live Run screen.
                  await ESP32Service
                      .stopPCR();

                  if (!mounted) {
                    return;
                  }

                  // Get the final ESP32 state after STOP.
                  // This ensures the PDF receives the final
                  // stopped state.
                  await _refreshStatus();

                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        "PCR stopped. Run data is preserved — you can download the report.",
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(
            height: 25,
          ),
        ],
      ),
    );
  }
}
