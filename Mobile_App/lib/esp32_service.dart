import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/live_status.dart';
import '../models/pcr_program.dart';
import '../models/pcr_temperature_sample.dart';

class ESP32Service {
  //==================================================
  // Local Settings
  //==================================================

  static const String _settingsBoxName =
      "esp32_settings";

  static const String _ipKey =
      "esp32_ip";

  static const String _defaultIP =
      "172.16.233.120";

  static Box? _settingsBox;

  // Host currently responding. Normally this is the saved IP.
  // If the IP changes after DHCP reassignment, the ESP32's mDNS
  // name can be used as a fallback when the platform resolves it.
  static String? _activeHost;

  //==================================================
  // Initialize
  //==================================================

  static Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_settingsBoxName)) {
        _settingsBox =
        await Hive.openBox(
          _settingsBoxName,
        );
      } else {
        _settingsBox =
            Hive.box(
              _settingsBoxName,
            );
      }

      if (!_settingsBox!.containsKey(_ipKey)) {
        await _settingsBox!.put(
          _ipKey,
          _defaultIP,
        );
      }

      debugPrint(
        "ESP32 SERVICE INITIALIZED",
      );

      debugPrint(
        "ESP32 IP: ${getIP()}",
      );
    } catch (e, s) {
      debugPrint(
        "ESP32 SERVICE INITIALIZATION FAILED",
      );

      debugPrint(
        e.toString(),
      );

      debugPrint(
        s.toString(),
      );
    }
  }

  //==================================================
  // Get IP
  //==================================================

  static String getIP() {
    try {
      if (_settingsBox != null &&
          _settingsBox!.isOpen) {
        final value =
        _settingsBox!.get(
          _ipKey,
          defaultValue: _defaultIP,
        );

        if (value != null &&
            value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
    } catch (e) {
      debugPrint(
        "Could not read ESP32 IP: $e",
      );
    }

    return _defaultIP;
  }

  //==================================================
  // Set IP
  //==================================================

  static Future<bool> setIP(
      String newIP,
      ) async {
    final ip = newIP.trim();

    if (ip.isEmpty) {
      return false;
    }

    try {
      if (_settingsBox == null ||
          !_settingsBox!.isOpen) {
        await init();
      }

      await _settingsBox!.put(
        _ipKey,
        ip,
      );

      _activeHost = null;

      debugPrint(
        "ESP32 IP UPDATED -> $ip",
      );

      return true;
    } catch (e, s) {
      debugPrint(
        "FAILED TO SAVE ESP32 IP",
      );

      debugPrint(
        e.toString(),
      );

      debugPrint(
        s.toString(),
      );

      return false;
    }
  }

  //==================================================
  // Base URL
  //==================================================

  static String get baseUrl {
    return "http://${_activeHost ?? getIP()}";
  }

  //==================================================
  // Ping
  //==================================================

  static Future<bool> ping() async {
    final hosts = <String>[
      getIP(),
      "pcr.local",
    ];

    final tried = <String>{};

    for (final host in hosts) {
      if (!tried.add(host)) {
        continue;
      }

      try {
        debugPrint("PING -> http://$host/ping");

        final response = await http
            .get(Uri.parse("http://$host/ping"))
            .timeout(const Duration(milliseconds: 700));

        debugPrint(
          "PING $host STATUS : ${response.statusCode}",
        );

        if (response.statusCode == 200) {
          _activeHost = host;
          return true;
        }
      } catch (e) {
        debugPrint("PING $host FAILED: $e");
      }
    }

    _activeHost = null;
    return false;
  }

  //==================================================
  // Set IP and Test
  //==================================================

  static Future<bool> setIPAndTest(
      String newIP,
      ) async {
    final saved =
    await setIP(
      newIP,
    );

    if (!saved) {
      return false;
    }

    return await ping();
  }

  //==================================================
  // GET LIVE STATUS
  //
  // ESP32 is authoritative.
  //
  // Flutter ONLY reads and displays this data.
  //==================================================

  static Future<LiveStatus?> getStatus({bool allowHostRecovery = true}) async {
    try {
      debugPrint(
        "------------------------------------------------",
      );

      debugPrint(
        "GET -> $baseUrl/status",
      );

      final response =
      await http
          .get(
        Uri.parse(
          "$baseUrl/status",
        ),
      )
          .timeout(
        const Duration(
          milliseconds: 2000,
        ),
      );

      debugPrint(
        "STATUS CODE : ${response.statusCode}",
      );

      // Avoid dumping the full status payload every second; it adds
      // unnecessary logging overhead during long PCR runs.

      if (response.statusCode != 200) {
        debugPrint("STATUS REQUEST RETURNED NON-200");
        return await _recoverStatusHost(allowHostRecovery);
      }

      //================================================
      // Decode JSON
      //================================================

      final dynamic decoded =
      jsonDecode(
        response.body,
      );

      if (decoded is! Map) {
        debugPrint("STATUS JSON IS NOT AN OBJECT");
        return await _recoverStatusHost(allowHostRecovery);
      }

      final Map<String, dynamic> json =
      Map<String, dynamic>.from(
        decoded,
      );

      debugPrint(
        "JSON PARSED SUCCESSFULLY",
      );

      //================================================
      // Print important values
      //================================================

      debugPrint(
        "TEMP   : ${json["temperature"]}",
      );

      debugPrint(
        "TARGET : ${json["target"]}",
      );

      debugPrint(
        "STAGE  : ${json["stage"]}",
      );

      debugPrint(
        "STAGE NAME : ${json["stageName"]}",
      );

      debugPrint(
        "PHASE  : ${json["phase"]}",
      );

      debugPrint(
        "CYCLE  : ${json["cycle"]}/${json["totalCycles"]}",
      );

      debugPrint(
        "RUNNING : ${json["running"]}",
      );

      debugPrint(
        "HOLD MS : ${json["holdRemainingMs"]}",
      );

      //================================================
      // Convert to LiveStatus
      //================================================

      final LiveStatus result =
      LiveStatus.fromJson(
        json,
      );

      debugPrint(
        "LIVE STATUS OBJECT CREATED",
      );

      debugPrint(
        result.toString(),
      );

      return result;
    } catch (e, s) {
      debugPrint(
        "STATUS REQUEST FAILED",
      );

      debugPrint(
        "ERROR: $e",
      );

      debugPrint(
        s.toString(),
      );

      return await _recoverStatusHost(allowHostRecovery);
    }
  }

  // If the saved DHCP address has changed, try the configured address and
  // then the ESP32 mDNS name once. Recovery is bounded to one fallback pass,
  // so a failed device cannot cause recursive/repeated probing each poll.
  static Future<LiveStatus?> _recoverStatusHost(bool allowRecovery) async {
    if (!allowRecovery) return null;
    final found = await ping();
    if (!found) return null;
    return getStatus(allowHostRecovery: false);
  }

  //==================================================
  // Recover ESP32-authoritative telemetry
  //
  // Flutter asks for samples AFTER the last sequence it has.
  // The ESP32 ring buffer fills any short Wi-Fi outage.
  //==================================================

  static Future<TelemetryBatch?> getTelemetrySince({
    required int runId,
    required int since,
    int limit = 64,
  }) async {
    try {
      final safeLimit = limit.clamp(1, 64);

      final uri = Uri.parse(
        "$baseUrl/telemetry"
            "?run=$runId"
            "&since=$since"
            "&limit=$safeLimit",
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 2));

      if (response.statusCode != 200) {
        debugPrint(
          "TELEMETRY STATUS : ${response.statusCode}",
        );
        return null;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        return null;
      }

      return TelemetryBatch.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (e) {
      debugPrint("TELEMETRY RECOVERY FAILED: $e");
      return null;
    }
  }

//==================================================
// Get Current PCR Program From ESP32
//
// This ONLY reads the currently loaded program.
// It does NOT start, stop, pause, resume,
// or modify the PCR.
//==================================================

  static Future<PCRProgram?> getProgram() async {
    try {
      debugPrint(
        "------------------------------------------------",
      );

      debugPrint(
        "GET -> $baseUrl/program",
      );

      final response =
      await http
          .get(
        Uri.parse(
          "$baseUrl/program",
        ),
      )
          .timeout(
        const Duration(
          seconds: 3,
        ),
      );

      debugPrint(
        "PROGRAM GET STATUS : ${response.statusCode}",
      );

      debugPrint(
        "PROGRAM GET BODY   : ${response.body}",
      );

      if (response.statusCode != 200) {
        debugPrint(
          "Server returned non-200 status while reading program.",
        );

        return null;
      }

      final dynamic decoded =
      jsonDecode(
        response.body,
      );

      if (decoded is! Map) {
        debugPrint(
          "PROGRAM JSON IS NOT AN OBJECT",
        );

        return null;
      }

      final Map<String, dynamic> json =
      Map<String, dynamic>.from(
        decoded,
      );

      debugPrint(
        "PCR PROGRAM PARSED SUCCESSFULLY",
      );

      return PCRProgram.fromMap(
        json,
      );
    } catch (e, s) {
      debugPrint(
        "PROGRAM GET FAILED",
      );

      debugPrint(
        e.toString(),
      );

      debugPrint(
        s.toString(),
      );

      return null;
    }
  }
  //==================================================
  // Start PCR
  //==================================================

  static Future<bool> startPCR() async {
    try {
      debugPrint(
        "GET -> $baseUrl/start",
      );

      final response =
      await http
          .get(
        Uri.parse(
          "$baseUrl/start",
        ),
      )
          .timeout(
        const Duration(
          seconds: 3,
        ),
      );

      debugPrint(
        "START STATUS : ${response.statusCode}",
      );

      debugPrint(
        "START BODY : ${response.body}",
      );

      return response.statusCode == 200;
    } catch (e, s) {
      debugPrint(
        "START FAILED",
      );

      debugPrint(
        e.toString(),
      );

      debugPrint(
        s.toString(),
      );

      return false;
    }
  }

  //==================================================
  // Pause PCR
  //==================================================

  static Future<bool> pausePCR() async {
    try {
      debugPrint(
        "GET -> $baseUrl/pause",
      );

      final response =
      await http
          .get(
        Uri.parse(
          "$baseUrl/pause",
        ),
      )
          .timeout(
        const Duration(
          seconds: 3,
        ),
      );

      debugPrint(
        "PAUSE STATUS : ${response.statusCode}",
      );

      return response.statusCode == 200;
    } catch (e, s) {
      debugPrint(
        "PAUSE FAILED",
      );

      debugPrint(
        e.toString(),
      );

      debugPrint(
        s.toString(),
      );

      return false;
    }
  }

  //==================================================
  // Resume PCR
  //==================================================

  static Future<bool> resumePCR() async {
    try {
      debugPrint(
        "GET -> $baseUrl/resume",
      );

      final response =
      await http
          .get(
        Uri.parse(
          "$baseUrl/resume",
        ),
      )
          .timeout(
        const Duration(
          seconds: 3,
        ),
      );

      debugPrint(
        "RESUME STATUS : ${response.statusCode}",
      );

      return response.statusCode == 200;
    } catch (e, s) {
      debugPrint(
        "RESUME FAILED",
      );

      debugPrint(
        e.toString(),
      );

      debugPrint(
        s.toString(),
      );

      return false;
    }
  }

  //==================================================
  // Stop PCR
  //==================================================

  static Future<bool> stopPCR() async {
    try {
      debugPrint(
        "GET -> $baseUrl/stop",
      );

      final response =
      await http
          .get(
        Uri.parse(
          "$baseUrl/stop",
        ),
      )
          .timeout(
        const Duration(
          seconds: 3,
        ),
      );

      debugPrint(
        "STOP STATUS : ${response.statusCode}",
      );

      return response.statusCode == 200;
    } catch (e, s) {
      debugPrint(
        "STOP FAILED",
      );

      debugPrint(
        e.toString(),
      );

      debugPrint(
        s.toString(),
      );

      return false;
    }
  }

  //==================================================
  // Upload PCR Program
  //==================================================

  static Future<bool> sendProgram(
      Map<String, dynamic> program,
      ) async {
    try {
      debugPrint(
        "POST -> $baseUrl/program",
      );

      final response =
      await http
          .post(
        Uri.parse(
          "$baseUrl/program",
        ),
        headers: {
          "Content-Type":
          "application/json",
        },
        body: jsonEncode(
          program,
        ),
      )
          .timeout(
        const Duration(
          seconds: 5,
        ),
      );

      debugPrint(
        "PROGRAM STATUS : ${response.statusCode}",
      );

      debugPrint(
        "PROGRAM BODY   : ${response.body}",
      );

      return response.statusCode == 200;
    } catch (e, s) {
      debugPrint(
        "PROGRAM UPLOAD FAILED",
      );

      debugPrint(
        e.toString(),
      );

      debugPrint(
        s.toString(),
      );

      return false;
    }
  }
}
