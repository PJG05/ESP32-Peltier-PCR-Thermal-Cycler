import 'package:flutter/material.dart';

import '../models/pcr_program.dart';
import '../models/pcr_stage.dart';
import '../utils/constants.dart';

class ProtocolService {
  static PCRProgram currentProgram = PCRProgram(
    name: "New PCR Program",

    initialTemp: PCRConstants.initialDenaturationTemp,
    initialHold: PCRConstants.initialDenaturationHold,

    stages: [

      PCRStage(
        stageName: "Denaturation",
        temperature: PCRConstants.denaturationTemp,
        holdTime: PCRConstants.denaturationHold,
        stageColor: Colors.red,
      ),

      PCRStage(
        stageName: "Annealing",
        temperature: PCRConstants.annealingTemp,
        holdTime: PCRConstants.annealingHold,
        stageColor: Colors.orange,
      ),

      PCRStage(
        stageName: "Extension",
        temperature: PCRConstants.extensionTemp,
        holdTime: PCRConstants.extensionHold,
        stageColor: Colors.green,
      ),

    ],

    cycles: PCRConstants.defaultCycles,

    finalTemp: PCRConstants.finalExtensionTemp,
    finalHold: PCRConstants.finalExtensionHold,
  );

  static void addStage() {

    currentProgram.stages.add(

      PCRStage(

        stageName: "Custom Stage",

        temperature: 60,

        holdTime: 30,

        stageColor: Colors.blue,

      ),

    );

  }

  static void removeStage(int index) {

    if (currentProgram.stages.length > 1) {

      currentProgram.stages.removeAt(index);

    }

  }

  static void clearProgram() {

    currentProgram = PCRProgram(

      name: "New PCR Program",

      initialTemp:
      PCRConstants.initialDenaturationTemp,

      initialHold:
      PCRConstants.initialDenaturationHold,

      stages: [

        PCRStage(

          stageName: "Denaturation",

          temperature:
          PCRConstants.denaturationTemp,

          holdTime:
          PCRConstants.denaturationHold,

          stageColor: Colors.red,

        ),

        PCRStage(

          stageName: "Annealing",

          temperature:
          PCRConstants.annealingTemp,

          holdTime:
          PCRConstants.annealingHold,

          stageColor: Colors.orange,

        ),

        PCRStage(

          stageName: "Extension",

          temperature:
          PCRConstants.extensionTemp,

          holdTime:
          PCRConstants.extensionHold,

          stageColor: Colors.green,

        ),

      ],

      cycles:
      PCRConstants.defaultCycles,

      finalTemp:
      PCRConstants.finalExtensionTemp,

      finalHold:
      PCRConstants.finalExtensionHold,

    );

  }
}