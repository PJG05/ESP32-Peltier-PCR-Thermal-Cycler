import 'dart:async';

import 'package:flutter/material.dart';

import 'create_program_screen.dart';
import 'saved_programs_screen.dart';
import '../models/pcr_stage.dart';
import '../models/pcr_program.dart';
import 'protocol_summary_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import '../services/esp32_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _connected = false;
  bool _testingConnection = false;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();

    _checkConnection();

    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => _checkConnection(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  //==================================================
  // CHECK ESP32 CONNECTION
  //==================================================

  Future<void> _checkConnection() async {
    if (_testingConnection) return;

    final ok = await ESP32Service.ping();

    if (!mounted) return;

    setState(() {
      _connected = ok;
    });
  }

  //==================================================
  // CHANGE ESP32 IP
  //==================================================

  Future<void> _changeESP32IP() async {
    final controller = TextEditingController(
      text: ESP32Service.getIP(),
    );

    bool saving = false;
    String statusMessage = "";

    Color statusColor = Colors.grey;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveAndTest() async {
              final newIP = controller.text.trim();

              if (newIP.isEmpty) {
                setDialogState(() {
                  statusMessage = "Please enter an IP address.";
                  statusColor = Colors.red;
                });
                return;
              }

              setDialogState(() {
                saving = true;
                statusMessage = "Connecting to ESP32...";
                statusColor = Colors.orange;
              });

              setState(() {
                _testingConnection = true;
              });

              final connected =
              await ESP32Service.setIPAndTest(newIP);

              if (!mounted) return;

              setState(() {
                _testingConnection = false;
                _connected = connected;
              });

              if (connected) {
                setDialogState(() {
                  saving = false;
                  statusMessage =
                  "ESP32 connected successfully!";
                  statusColor = Colors.green;
                });

                await Future.delayed(
                  const Duration(milliseconds: 700),
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } else {
                setDialogState(() {
                  saving = false;
                  statusMessage =
                  "Couldn't connect to ESP32.";
                  statusColor = Colors.red;
                });
              }
            }

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.wifi,
                    color: Colors.blue,
                  ),
                  SizedBox(width: 10),
                  Text("ESP32 Connection"),
                ],
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ESP32 IP Address",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: controller,
                    enabled: !saving,
                    keyboardType:
                    TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "Example: 172.16.233.238",
                      prefixIcon:
                      const Icon(Icons.computer),
                      border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  if (statusMessage.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          statusColor == Colors.green
                              ? Icons.check_circle
                              : statusColor == Colors.red
                              ? Icons.error
                              : Icons.sync,
                          color: statusColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusMessage,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text("Cancel"),
                ),

                ElevatedButton.icon(
                  onPressed:
                  saving ? null : saveAndTest,
                  icon: saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.wifi_find),
                  label: Text(
                    saving
                        ? "Testing..."
                        : "Save & Test",
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  //==================================================
  // BUILD
  //==================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PCR"),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            children: [

              //----------------------------------------------------------
              // NCBS + TIFR LOGOS
              //----------------------------------------------------------

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [

                  Image.asset(
                    "assets/images/ncbslogo.png",
                    height: 75,
                  ),

                  Image.asset(
                    "assets/images/tifrlogo.jpeg",
                    height: 75,
                  ),
                ],
              ),

              const SizedBox(height: 25),

              //----------------------------------------------------------
              // PCR ICON
              //----------------------------------------------------------

              const Icon(
                Icons.science,
                size: 100,
                color: Colors.blue,
              ),

              const SizedBox(height: 20),

              //----------------------------------------------------------
              // TITLE
              //----------------------------------------------------------

              const Text(
                "PCR CONTROL SYSTEM",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 40),

              //----------------------------------------------------------
              // CREATE PROGRAM
              //----------------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 60,

                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),

                  label: const Text(
                    "Create Program",
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),

                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const CreateProgramScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 15),

              //----------------------------------------------------------
              // SAVED PROGRAMS
              //----------------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 60,

                child: ElevatedButton.icon(
                  icon: const Icon(Icons.folder),

                  label: const Text(
                    "Saved Programs",
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),

                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const SavedProgramsScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 15),

              //----------------------------------------------------------
              // LIVE RUN
              //----------------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 60,

                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.play_arrow,
                  ),

                  label: const Text(
                    "Live Run",
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),

                  onPressed: () {
                    final demoProgram =
                    PCRProgram(
                      name: "Default Program",

                      initialTemp: 95,
                      initialHold: 180,

                      stages: [
                        PCRStage(
                          stageName:
                          "Denaturation",
                          temperature: 95,
                          holdTime: 30,
                          stageColor: Colors.red,
                        ),

                        PCRStage(
                          stageName: "Annealing",
                          temperature: 60,
                          holdTime: 30,
                          stageColor: Colors.blue,
                        ),

                        PCRStage(
                          stageName: "Extension",
                          temperature: 72,
                          holdTime: 45,
                          stageColor:
                          Colors.green,
                        ),
                      ],

                      cycles: 35,

                      finalTemp: 72,
                      finalHold: 300,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProtocolSummaryScreen(
                              program: demoProgram,
                            ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 15),

              //----------------------------------------------------------
              // SETTINGS
              //----------------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 60,

                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.settings,
                  ),

                  label: const Text(
                    "Settings",
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),

                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 15),

              //----------------------------------------------------------
              // ABOUT
              //----------------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 60,

                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.info,
                  ),

                  label: const Text(
                    "About",
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),

                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const AboutScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              //----------------------------------------------------------
              // ESP32 STATUS
              //----------------------------------------------------------

              Card(
                elevation: 4,

                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16),
                ),

                child: Padding(
                  padding:
                  const EdgeInsets.all(18),

                  child: Column(
                    children: [

                      //--------------------------------------------------
                      // HEADER
                      //--------------------------------------------------

                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(
                            _connected
                                ? Icons.wifi
                                : Icons.wifi_off,
                            color: _connected
                                ? Colors.green
                                : Colors.red,
                          ),

                          const SizedBox(width: 8),

                          const Text(
                            "ESP32 STATUS",
                            style: TextStyle(
                              fontWeight:
                              FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      //--------------------------------------------------
                      // CONNECTION STATUS
                      //--------------------------------------------------

                      Text(
                        _connected
                            ? "Connected"
                            : "Disconnected",
                        style: TextStyle(
                          color: _connected
                              ? Colors.green
                              : Colors.red,
                          fontSize: 22,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      //--------------------------------------------------
                      // CURRENT IP
                      //--------------------------------------------------

                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),

                        decoration:
                        BoxDecoration(
                          color: Colors.grey
                              .withOpacity(0.10),
                          borderRadius:
                          BorderRadius.circular(
                              10),
                        ),

                        child: Row(
                          children: [

                            const Icon(
                              Icons.computer,
                              size: 20,
                              color: Colors.grey,
                            ),

                            const SizedBox(
                                width: 10),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [

                                  const Text(
                                    "ESP32 IP Address",
                                    style:
                                    TextStyle(
                                      color:
                                      Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),

                                  const SizedBox(
                                      height: 3),

                                  Text(
                                    ESP32Service
                                        .getIP(),
                                    style:
                                    const TextStyle(
                                      fontWeight:
                                      FontWeight
                                          .bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            IconButton(
                              tooltip:
                              "Change ESP32 IP",
                              icon: const Icon(
                                Icons.edit,
                                color:
                                Colors.blue,
                              ),
                              onPressed:
                              _testingConnection
                                  ? null
                                  : _changeESP32IP,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      //--------------------------------------------------
                      // CHANGE IP BUTTON
                      //--------------------------------------------------

                      SizedBox(
                        width: double.infinity,

                        child:
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.wifi_find,
                          ),

                          label: const Text(
                            "Change IP / Test Connection",
                          ),

                          onPressed:
                          _testingConnection
                              ? null
                              : _changeESP32IP,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}