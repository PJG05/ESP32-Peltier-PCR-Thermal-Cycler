import 'package:flutter/material.dart';

import '../models/pcr_stage.dart';

class StageCard extends StatelessWidget {
  final PCRStage stage;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onTemperatureChanged;
  final ValueChanged<String>? onHoldChanged;

  const StageCard({
    super.key,
    required this.stage,
    this.onDelete,
    this.onTemperatureChanged,
    this.onHoldChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),

      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: stage.stageColor,
              width: 8,
            ),
          ),
        ),

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [

              Row(
                children: [

                  Expanded(
                    child: Text(
                      stage.stageName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: stage.stageColor,
                      ),
                    ),
                  ),

                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 15),

              Row(
                children: [

                  Expanded(
                    child: TextFormField(
                      initialValue:
                      stage.temperature.toString(),

                      keyboardType:
                      const TextInputType.numberWithOptions(
                        decimal: true,
                      ),

                      decoration:
                      const InputDecoration(
                        labelText: "Temperature (°C)",
                        border: OutlineInputBorder(),
                        prefixIcon:
                        Icon(Icons.thermostat),
                      ),

                      onChanged:
                      onTemperatureChanged,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: TextFormField(
                      initialValue:
                      stage.holdTime.toString(),

                      keyboardType:
                      TextInputType.number,

                      decoration:
                      const InputDecoration(
                        labelText: "Hold (sec)",
                        border: OutlineInputBorder(),
                        prefixIcon:
                        Icon(Icons.timer),
                      ),

                      onChanged:
                      onHoldChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}