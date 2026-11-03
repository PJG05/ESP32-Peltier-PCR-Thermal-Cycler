import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),

        children: [

          const Text(
            "PCR Controller Settings",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Card(
            child: ListTile(
              leading: const Icon(Icons.wifi),
              title: const Text("ESP32 IP Address"),
              subtitle: const Text(
                "Configured in esp32_service.dart",
              ),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.memory),
              title: const Text("Firmware"),
              subtitle: const Text("Version 2.0.0"),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.thermostat),
              title: const Text("Temperature Sensor"),
              subtitle: const Text("PT1000 + MAX31865"),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.speed),
              title: const Text("TEC Driver"),
              subtitle: const Text("IBT-4 H-Bridge"),
            ),
          ),

          const SizedBox(height: 25),

          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("More settings coming soon"),
                ),
              );
            },

            icon: const Icon(Icons.build),

            label: const Text("Advanced Settings"),
          ),

        ],
      ),
    );
  }
}