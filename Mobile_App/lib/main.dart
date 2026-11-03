import 'package:flutter/material.dart';

import 'Screens/home_screen.dart';
import 'Services/storage_service.dart';
import 'services/esp32_service.dart';
import 'screens/splash_screen.dart';
import 'screens/live_run_screen.dart';

import 'models/live_status.dart';
import 'models/pcr_program.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //==================================================
  // LOCAL STORAGE
  //==================================================

  await StorageService.init();

  //==================================================
  // ESP32 SERVICE
  //==================================================

  await ESP32Service.init();

  //==================================================
  // CHECK FOR AN EXISTING PCR RUN
  //
  // IMPORTANT:
  //
  // ESP32 is the authority.
  //
  // This only READS the current state.
  //
  // It NEVER starts, stops, pauses, resumes,
  // or modifies the PCR.
  //==================================================

  Widget initialScreen =
  const SplashScreen();

  try {

    final LiveStatus? startupStatus =
    await ESP32Service.getStatus();

    //================================================
    // PCR CURRENTLY RUNNING
    //================================================

    if (startupStatus != null &&
        startupStatus.running) {

      debugPrint(
        "==========================================",
      );

      debugPrint(
        "PCR RUN DETECTED DURING APP STARTUP",
      );

      debugPrint(
        "Cycle: ${startupStatus.cycle}/${startupStatus.totalCycles}",
      );

      debugPrint(
        "Stage: ${startupStatus.stageName}",
      );

      debugPrint(
        "Phase: ${startupStatus.phase}",
      );

      debugPrint(
        "Temperature: ${startupStatus.temperature}",
      );

      debugPrint(
        "Target: ${startupStatus.target}",
      );

      debugPrint(
        "==========================================",
      );

      //================================================
      // GET PROGRAM FROM ESP32
      //
      // This allows LiveRunScreen to display the
      // correct PCR program after the Flutter app
      // has been completely closed.
      //================================================

      final PCRProgram? recoveredProgram =
      await ESP32Service.getProgram();

      if (recoveredProgram != null) {

        initialScreen =
            LiveRunScreen(
              program: recoveredProgram,
            );

      } else {

        debugPrint(
          "PCR is running but program recovery failed.",
        );

        // Do NOT start or modify PCR.
        // Fall back to normal app.
        initialScreen =
        const SplashScreen();
      }
    }

    //================================================
    // PCR NOT RUNNING
    //
    // Normal application startup.
    //================================================

    else {

      debugPrint(
        "No active PCR run detected.",
      );

      initialScreen =
      const SplashScreen();
    }

  } catch (e) {

    //================================================
    // ESP32 UNAVAILABLE
    //
    // NEVER let a communication failure affect PCR.
    //================================================

    debugPrint(
      "STARTUP PCR RECOVERY CHECK FAILED: $e",
    );

    initialScreen =
    const SplashScreen();
  }

  //==================================================
  // START APPLICATION
  //==================================================

  runApp(
    PCRApp(
      initialScreen: initialScreen,
    ),
  );
}

class PCRApp extends StatelessWidget {

  final Widget initialScreen;

  const PCRApp({
    super.key,
    required this.initialScreen,
  });

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title:
      'PCR Controller',

      theme:
      ThemeData(
        primarySwatch:
        Colors.blue,

        useMaterial3:
        true,
      ),

      home:
      initialScreen,
    );
  }
}