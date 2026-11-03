import 'package:flutter/material.dart';

class PCRConstants {
  // Default Temperatures

  static const double initialDenaturationTemp = 95.0;
  static const int initialDenaturationHold = 180;

  static const double denaturationTemp = 95.0;
  static const int denaturationHold = 15;

  static const double annealingTemp = 60.0;
  static const int annealingHold = 30;

  static const double extensionTemp = 72.0;
  static const int extensionHold = 30;

  static const double finalExtensionTemp = 72.0;
  static const int finalExtensionHold = 300;

  static const double holdTemperature = 4.0;

  static const int defaultCycles = 35;

  // Limits

  static const double minTemperature = 4;
  static const double maxTemperature = 100;

  static const int minHold = 0;
  static const int maxHold = 7200;

  // Colors

  static const Color denaturationColor =
      Colors.red;

  static const Color annealingColor =
      Colors.orange;

  static const Color extensionColor =
      Colors.green;

  static const Color holdColor =
      Colors.blue;
}