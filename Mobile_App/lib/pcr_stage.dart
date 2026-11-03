import 'package:flutter/material.dart';

class PCRStage {
  String stageName;
  double temperature;
  int holdTime;
  Color stageColor;

  PCRStage({
    required this.stageName,
    required this.temperature,
    required this.holdTime,
    required this.stageColor,
  });

  Map<String, dynamic> toMap() {
    return {
      'stageName': stageName,
      'temperature': temperature,
      'holdTime': holdTime,
      'stageColor': stageColor.value,
    };
  }

  factory PCRStage.fromMap(Map map) {
    return PCRStage(
      stageName: map['stageName'],
      temperature: map['temperature'],
      holdTime: map['holdTime'],
      stageColor: Color(map['stageColor']),
    );
  }
}