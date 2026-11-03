import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Widget infoTile(
      String title,
      String value,
      IconData icon,
      ) {
    return Card(
      elevation: 3,
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.blue,
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("About"),
        centerTitle: true,
      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(20),

        child: Column(

          children: [

            //----------------------------------------------------------
            // Logos
            //----------------------------------------------------------

            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,

              children: [

                Image.asset(
                  "assets/images/ncbslogo.png",
                  height: 70,
                ),

                Image.asset(
                  "assets/images/tifrlogo.jpeg",
                  height: 70,
                ),

              ],
            ),

            const SizedBox(height: 30),

            const Icon(
              Icons.science,
              size: 90,
              color: Colors.blue,
            ),

            const SizedBox(height: 20),

            const Text(
              "PCR CONTROL SYSTEM",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Version 2.0.0",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 35),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Instrument Information",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),

            const SizedBox(height: 10),

            infoTile(
              "Firmware",
              "2.0.0",
              Icons.memory,
            ),

            infoTile(
              "Controller",
              "ESP32",
              Icons.developer_board,
            ),

            infoTile(
              "Thermal Control",
              "Bang-Bang",
              Icons.thermostat,
            ),

            infoTile(
              "Communication",
              "WiFi",
              Icons.wifi,
            ),

            infoTile(
              "Organization",
              "NCBS",
              Icons.apartment,
            ),

            infoTile(
              "Division",
              "Instrumentation",
              Icons.build,
            ),

            const SizedBox(height: 30),

            const Divider(),

            const SizedBox(height: 15),

            const Text(
              "Developed at",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "National Centre for Biological Sciences",
              textAlign: TextAlign.center,
            ),

            const Text(
              "Tata Institute of Fundamental Research",
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            const Text(
              "© 2026 NCBS",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 15),

          ],
        ),
      ),
    );
  }
}