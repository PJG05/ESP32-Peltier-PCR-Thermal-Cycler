import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pcr_program.dart';
import '../services/esp32_service.dart';

import 'home_screen.dart';
import 'live_run_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
  });

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    _checkPCRState();
  }

  //==================================================
  // Check ESP32 PCR State
  //==================================================

  Future<void> _checkPCRState() async {

    //------------------------------------------------
    // Give the splash screen a little time to appear
    //------------------------------------------------

    await Future.delayed(
      const Duration(seconds: 1),
    );

    //------------------------------------------------
    // Ask ESP32 for the REAL PCR state
    //------------------------------------------------

    final status =
    await ESP32Service.getStatus();

    //------------------------------------------------
    // ESP32 unreachable
    //------------------------------------------------

    if (status == null) {

      if (!mounted)
        return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
          const HomeScreen(),
        ),
      );

      return;
    }

    //------------------------------------------------
    // PCR is currently running
    //------------------------------------------------

    if (status.running) {

      //------------------------------------------------
      // Get the program from ESP32
      //------------------------------------------------

      final program =
      await ESP32Service.getProgram();

      //------------------------------------------------
      // Program successfully recovered
      //------------------------------------------------

      if (program != null) {

        if (!mounted)
          return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                LiveRunScreen(
                  program: program,
                ),
          ),
        );

        return;
      }
    }

    //------------------------------------------------
    // No active PCR
    //------------------------------------------------

    if (!mounted)
      return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const HomeScreen(),
      ),
    );
  }

  //==================================================
  // UI
  //==================================================

  @override
  Widget build(
      BuildContext context,
      ) {

    return Scaffold(

      backgroundColor:
      Colors.white,

      body: Center(

        child: Column(

          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [

            Row(

              mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,

              children: [

                Image.asset(
                  "assets/images/ncbslogo.png",
                  height: 80,
                ),

                Image.asset(
                  "assets/images/tifrlogo.jpeg",
                  height: 80,
                ),

              ],
            ),

            const SizedBox(
              height: 40,
            ),

            const Icon(
              Icons.science,
              size: 120,
              color: Colors.blue,
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              "PCR CONTROL SYSTEM",
              style: TextStyle(
                fontSize: 30,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              "Version 2.0",
              style: TextStyle(
                fontSize: 18,
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            const Text(
              "National Centre for Biological Sciences",
              style: TextStyle(
                fontSize: 17,
              ),
            ),

            const Text(
              "Tata Institute of Fundamental Research",
              style: TextStyle(
                fontSize: 17,
              ),
            ),

            const SizedBox(
              height: 50,
            ),

            const CircularProgressIndicator(),

            const SizedBox(
              height: 15,
            ),

            const Text(
              "Checking PCR status...",
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}