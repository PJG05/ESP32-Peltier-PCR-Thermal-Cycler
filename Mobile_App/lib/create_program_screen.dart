
import 'package:flutter/material.dart';

import '../models/pcr_program.dart';
import '../models/pcr_stage.dart';
import '../services/protocol_service.dart';
import '../services/storage_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/program_info_card.dart';
import '../widgets/stage_card.dart';
import 'protocol_summary_screen.dart';

class CreateProgramScreen extends StatefulWidget {
  const CreateProgramScreen({super.key});

  @override
  State<CreateProgramScreen> createState() => _CreateProgramScreenState();
}

class _CreateProgramScreenState extends State<CreateProgramScreen> {
  late TextEditingController _programName;
  late TextEditingController _initialTemp;
  late TextEditingController _initialHold;
  late TextEditingController _cycles;
  late TextEditingController _finalTemp;
  late TextEditingController _finalHold;

  @override
  void initState() {
    super.initState();
    final p = ProtocolService.currentProgram;
    _programName = TextEditingController(text: p.name);
    _initialTemp = TextEditingController(text: p.initialTemp.toString());
    _initialHold = TextEditingController(text: p.initialHold.toString());
    _cycles = TextEditingController(text: p.cycles.toString());
    _finalTemp = TextEditingController(text: p.finalTemp.toString());
    _finalHold = TextEditingController(text: p.finalHold.toString());
  }

  @override
  void dispose() {
    _programName.dispose();
    _initialTemp.dispose();
    _initialHold.dispose();
    _cycles.dispose();
    _finalTemp.dispose();
    _finalHold.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prog = PCRProgram(
      name: _programName.text,
      initialTemp: double.tryParse(_initialTemp.text) ?? 95,
      initialHold: int.tryParse(_initialHold.text) ?? 180,
      stages: ProtocolService.currentProgram.stages,
      cycles: int.tryParse(_cycles.text) ?? 35,
      finalTemp: double.tryParse(_finalTemp.text) ?? 72,
      finalHold: int.tryParse(_finalHold.text) ?? 300,
    );

    await StorageService.saveProgram(prog);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Program Saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stages = ProtocolService.currentProgram.stages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PCR Program'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ProgramInfoCard(controller: _programName),
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Initial Denaturation',
                        style: TextStyle(fontWeight: FontWeight.bold,fontSize:18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _initialTemp,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Temperature (°C)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _initialHold,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Hold (sec)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height:20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PCR Cycling',
                style: TextStyle(fontSize:20,fontWeight:FontWeight.bold),
              ),
            ),

            const SizedBox(height:10),

            ...List.generate(stages.length, (i){
              return StageCard(
                stage: stages[i],
                onDelete: (){
                  setState(() {
                    ProtocolService.removeStage(i);
                  });
                },
                onTemperatureChanged: (v){
                  stages[i].temperature = double.tryParse(v) ?? stages[i].temperature;
                },
                onHoldChanged: (v){
                  stages[i].holdTime = int.tryParse(v) ?? stages[i].holdTime;
                },
              );
            }),

            const SizedBox(height:8),

            CustomButton(
              text: 'Add Stage',
              icon: Icons.add,
              color: Colors.blue,
              onPressed: (){
                setState(() {
                  ProtocolService.addStage();
                });
              },
            ),

            const SizedBox(height:20),

            TextField(
              controller: _cycles,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cycles',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height:20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children:[
                    Expanded(
                      child: TextField(
                        controller:_finalTemp,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText:'Final Extension (°C)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width:12),
                    Expanded(
                      child: TextField(
                        controller:_finalHold,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText:'Hold (sec)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height:16),

            const Card(
              child: ListTile(
                leading: Icon(Icons.ac_unit,color: Colors.blue),
                title: Text('Final Hold'),
                subtitle: Text('4°C (Infinite)'),
              ),
            ),

            const SizedBox(height:24),

            Row(
              children:[
                Expanded(
                  child: CustomButton(
                    text:'Save',
                    icon: Icons.save,
                    color: Colors.blue,
                    onPressed:_save,
                  ),
                ),
                const SizedBox(width:12),
                Expanded(
                  child: CustomButton(
                    text: 'Start',
                    icon: Icons.play_arrow,
                    color: Colors.green,
                    onPressed: () {
                      final program = PCRProgram(
                        name: _programName.text,
                        initialTemp: double.tryParse(_initialTemp.text) ?? 95,
                        initialHold: int.tryParse(_initialHold.text) ?? 180,
                        stages: ProtocolService.currentProgram.stages,
                        cycles: int.tryParse(_cycles.text) ?? 35,
                        finalTemp: double.tryParse(_finalTemp.text) ?? 72,
                        finalHold: int.tryParse(_finalHold.text) ?? 300,
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProtocolSummaryScreen(
                            program: program,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height:30),
          ],
        ),
      ),
    );
  }
}

