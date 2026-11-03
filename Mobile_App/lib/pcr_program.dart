import 'pcr_stage.dart';

class PCRProgram {
  String name;

  double initialTemp;
  int initialHold;

  List<PCRStage> stages;

  int cycles;

  double finalTemp;
  int finalHold;

  PCRProgram({
    required this.name,
    required this.initialTemp,
    required this.initialHold,
    required this.stages,
    required this.cycles,
    required this.finalTemp,
    required this.finalHold,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'initialTemp': initialTemp,
      'initialHold': initialHold,
      'stages': stages.map((e) => e.toMap()).toList(),
      'cycles': cycles,
      'finalTemp': finalTemp,
      'finalHold': finalHold,
    };
  }

  factory PCRProgram.fromMap(Map<String, dynamic> map) {
    return PCRProgram(
      name: map['name'] ?? '',

      initialTemp:
      (map['initialTemp'] as num?)?.toDouble() ?? 95,

      initialHold:
      map['initialHold'] ?? 180,

      stages: (map['stages'] as List? ?? [])
          .map(
            (e) => PCRStage.fromMap(
          Map<String, dynamic>.from(e),
        ),
      )
          .toList(),

      cycles: map['cycles'] ?? 35,

      finalTemp:
      (map['finalTemp'] as num?)?.toDouble() ?? 72,

      finalHold:
      map['finalHold'] ?? 300,
    );
  }
}