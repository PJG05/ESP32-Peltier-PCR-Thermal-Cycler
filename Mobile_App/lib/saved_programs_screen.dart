import 'package:flutter/material.dart';

import '../models/pcr_program.dart';
import '../services/storage_service.dart';
import 'create_program_screen.dart';
import 'protocol_summary_screen.dart';

class SavedProgramsScreen extends StatefulWidget {
  const SavedProgramsScreen({super.key});

  @override
  State<SavedProgramsScreen> createState() =>
      _SavedProgramsScreenState();
}

class _SavedProgramsScreenState
    extends State<SavedProgramsScreen> {
  List<PCRProgram> programs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  //--------------------------------------------------
  // Load Saved Programs
  //--------------------------------------------------

  void _load() {
    setState(() {
      programs = StorageService.getPrograms();
    });
  }

  //--------------------------------------------------
  // Delete Program
  //--------------------------------------------------

  Future<void> _delete(int index) async {
    await StorageService.deleteProgram(index);
    _load();
  }

  //--------------------------------------------------
  // UI
  //--------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Programs"),
      ),

      //--------------------------------------------------
      // Add New Program
      //--------------------------------------------------

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
              const CreateProgramScreen(),
            ),
          );

          _load();
        },
      ),

      //--------------------------------------------------
      // Body
      //--------------------------------------------------

      body: programs.isEmpty
          ? const Center(
        child: Text(
          "No saved PCR programs",
          style: TextStyle(
            fontSize: 18,
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: programs.length,
        itemBuilder: (context, index) {
          final p = programs[index];

          return Card(
            elevation: 3,

            child: ListTile(

              //--------------------------------------------------
              // Icon
              //--------------------------------------------------

              leading: const CircleAvatar(
                child: Icon(Icons.science),
              ),

              //--------------------------------------------------
              // Program Name
              //--------------------------------------------------

              title: Text(
                p.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              //--------------------------------------------------
              // Program Details
              //--------------------------------------------------

              subtitle: Text(
                "${p.cycles} Cycles • ${p.stages.length} Stages",
              ),

              //--------------------------------------------------
              // Buttons
              //--------------------------------------------------

              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  //------------------------------------------
                  // PLAY
                  //------------------------------------------

                  IconButton(
                    tooltip: "Run Program",
                    icon: const Icon(
                      Icons.play_arrow,
                      color: Colors.green,
                    ),
                    onPressed: () {

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProtocolSummaryScreen(
                                program: p,
                              ),
                        ),
                      );

                    },
                  ),

                  //------------------------------------------
                  // DELETE
                  //------------------------------------------

                  IconButton(
                    tooltip: "Delete Program",
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    onPressed: () => _delete(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}