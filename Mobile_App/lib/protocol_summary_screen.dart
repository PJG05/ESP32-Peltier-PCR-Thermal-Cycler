import 'package:flutter/material.dart';

import '../models/pcr_program.dart';
import '../services/esp32_service.dart';
import 'live_run_screen.dart';

class ProtocolSummaryScreen extends StatefulWidget {
  final PCRProgram program;

  const ProtocolSummaryScreen({
    super.key,
    required this.program,
  });

  @override
  State<ProtocolSummaryScreen> createState() =>
      _ProtocolSummaryScreenState();
}

class _ProtocolSummaryScreenState
    extends State<ProtocolSummaryScreen> {
  bool _starting = false;

  PCRProgram get program => widget.program;

  //--------------------------------------------------
  // Estimated Runtime
  //--------------------------------------------------

  int get estimatedSeconds {
    int total = program.initialHold + program.finalHold;

    int cycle = 0;

    for (final s in program.stages) {
      cycle += s.holdTime;
    }

    total += cycle * program.cycles;

    return total;
  }

  String get estimatedTime {
    final d = Duration(seconds: estimatedSeconds);

    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);

    return "${h}h ${m}m ${s}s";
  }

  //--------------------------------------------------
  // Helper Card
  //--------------------------------------------------

  Widget item(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  //--------------------------------------------------
  // Progress Dialog
  //--------------------------------------------------

  Future<void> _showProgressDialog(String message) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            const CircularProgressIndicator(),

            const SizedBox(height: 20),

            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

          ],
        ),
      ),
    );

    await Future.delayed(
      const Duration(milliseconds: 700),
    );
  }

  //--------------------------------------------------
  // Start PCR
  //--------------------------------------------------

  Future<void> _startRun() async {

    if (_starting) return;

    setState(() => _starting = true);

    final messenger =
    ScaffoldMessenger.of(context);

    //--------------------------------------------------
    // Upload Program
    //--------------------------------------------------

    await _showProgressDialog(
      "Uploading PCR Program...",
    );

    final uploaded =
    await ESP32Service.sendProgram(
      program.toMap(),
    );

    if (mounted) Navigator.pop(context);

    if (!uploaded) {

      if (!mounted) return;

      setState(() => _starting = false);

      messenger.showSnackBar(

        const SnackBar(

          backgroundColor: Colors.red,

          content: Text(
            "Couldn't upload the PCR program to the ESP32.",
          ),

        ),

      );

      return;
    }

    //--------------------------------------------------
    // Start PCR
    //--------------------------------------------------

    await _showProgressDialog(
      "Starting PCR...",
    );

    final started =
    await ESP32Service.startPCR();

    if (mounted) Navigator.pop(context);

    if (!started) {

      if (!mounted) return;

      setState(() => _starting = false);

      messenger.showSnackBar(

        const SnackBar(

          backgroundColor: Colors.red,

          content: Text(
            "ESP32 refused to start the PCR.",
          ),

        ),

      );

      return;
    }

    //--------------------------------------------------
    // Opening Monitor
    //--------------------------------------------------

    await _showProgressDialog(
      "Opening Live Monitor...",
    );

    if (mounted) Navigator.pop(context);

    if (!mounted) return;

    setState(() => _starting = false);

    Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => LiveRunScreen(
          program: program,
        ),

      ),

    );
  }

  //--------------------------------------------------
  // UI
  //--------------------------------------------------

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Protocol Summary",
        ),
      ),

      body: ListView(

        padding: const EdgeInsets.all(16),

        children: [

          item(
            "Program",
            program.name,
          ),

          item(
            "Initial Denaturation",
            "${program.initialTemp}°C • ${program.initialHold}s",
          ),

          item(
            "Cycles",
            program.cycles.toString(),
          ),

          const SizedBox(height: 8),

          const Text(
            "PCR Stages",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          ...program.stages.map(

                (s) => Card(

              child: ListTile(

                leading: CircleAvatar(
                  backgroundColor: s.stageColor,
                ),

                title: Text(
                  s.stageName,
                ),

                subtitle: Text(
                  "${s.temperature}°C",
                ),

                trailing: Text(
                  "${s.holdTime}s",
                ),

              ),

            ),

          ),

          item(
            "Final Extension",
            "${program.finalTemp}°C • ${program.finalHold}s",
          ),

          item(
            "Estimated Runtime",
            estimatedTime,
          ),

          const SizedBox(height: 20),

          Row(

            children: [

              Expanded(

                child: OutlinedButton(

                  onPressed: _starting
                      ? null
                      : () => Navigator.pop(context),

                  child: const Text(
                    "Back",
                  ),

                ),

              ),

              const SizedBox(width: 12),

              Expanded(

                child: ElevatedButton.icon(

                  icon: _starting

                      ? const SizedBox(

                    width: 18,
                    height: 18,

                    child: CircularProgressIndicator(

                      strokeWidth: 2,

                      color: Colors.white,

                    ),

                  )

                      : const Icon(
                    Icons.play_arrow,
                  ),

                  label: Text(

                    _starting
                        ? "Starting..."
                        : "Start Run",

                  ),

                  onPressed: _starting
                      ? null
                      : _startRun,

                ),

              ),

            ],

          ),

        ],

      ),

    );
  }
}