class LiveStatus {
    final double temperature;
    final double target;

    final bool heater;
    final bool cooling;
    final bool running;

    // PCR information
    final String stage;
    final String stageName;
    final String phase;

    final int cycle;
    final int totalCycles;

    // Legacy seconds value
    final int holdRemaining;

    // ESP32-authoritative precise value
    final int holdRemainingMs;

    final double resistance;

    // ESP32-authoritative telemetry synchronization metadata.
    // These values never control PCR execution.
    final int telemetryRunId;
    final int telemetrySequence;
    final int telemetryOldestSequence;

    LiveStatus({
        required this.temperature,
        required this.target,
        required this.heater,
        required this.cooling,
        required this.running,
        required this.stage,
        required this.stageName,
        required this.phase,
        required this.cycle,
        required this.totalCycles,
        required this.holdRemaining,
        required this.holdRemainingMs,
        required this.resistance,
        this.telemetryRunId = 0,
        this.telemetrySequence = 0,
        this.telemetryOldestSequence = 0,
    });

    //==================================================
    // Safe conversion helpers
    //==================================================

    static double _toDouble(dynamic value) {
        if (value == null) {
            return 0.0;
        }

        if (value is num) {
            return value.toDouble();
        }

        return double.tryParse(
            value.toString(),
        ) ??
            0.0;
    }

    static int _toInt(dynamic value) {
        if (value == null) {
            return 0;
        }

        if (value is num) {
            return value.toInt();
        }

        return int.tryParse(
            value.toString(),
        ) ??
            0;
    }

    static bool _toBool(dynamic value) {
        if (value is bool) {
            return value;
        }

        if (value is num) {
            return value != 0;
        }

        if (value is String) {
            final text = value.toLowerCase().trim();

            return text == "true" ||
                text == "1" ||
                text == "on";
        }

        return false;
    }

    static String _toString(
        dynamic value,
        String fallback,
        ) {
        if (value == null) {
            return fallback;
        }

        return value.toString();
    }

    //==================================================
    // JSON -> LiveStatus
    //==================================================

    factory LiveStatus.fromJson(
        Map<String, dynamic> json,
        ) {
        final int holdSeconds =
        _toInt(
            json["holdRemaining"],
        );

        final int preciseHoldMs =
        json.containsKey("holdRemainingMs")
            ? _toInt(
            json["holdRemainingMs"],
        )
            : holdSeconds * 1000;

        final result = LiveStatus(
            temperature:
            _toDouble(
                json["temperature"],
            ),

            target:
            _toDouble(
                json["target"],
            ),

            heater:
            _toBool(
                json["heater"],
            ),

            cooling:
            _toBool(
                json["cooling"],
            ),

            running:
            _toBool(
                json["running"],
            ),

            stage:
            _toString(
                json["stage"],
                "IDLE",
            ),

            stageName:
            _toString(
                json["stageName"],
                "Idle",
            ),

            phase:
            _toString(
                json["phase"],
                "Idle",
            ),

            cycle:
            _toInt(
                json["cycle"],
            ),

            totalCycles:
            _toInt(
                json["totalCycles"],
            ),

            holdRemaining:
            holdSeconds,

            holdRemainingMs:
            preciseHoldMs,

            resistance:
            _toDouble(
                json["resistance"],
            ),

            telemetryRunId:
            _toInt(
                json["telemetryRunId"],
            ),

            telemetrySequence:
            _toInt(
                json["telemetrySequence"],
            ),

            telemetryOldestSequence:
            _toInt(
                json["telemetryOldestSequence"],
            ),
        );

        return result;
    }

    //==================================================
    // Debug description
    //==================================================

    @override
    String toString() {
        return
            "LiveStatus("
                "temperature=$temperature, "
                "target=$target, "
                "heater=$heater, "
                "cooling=$cooling, "
                "running=$running, "
                "stage=$stage, "
                "stageName=$stageName, "
                "phase=$phase, "
                "cycle=$cycle/$totalCycles, "
                "holdRemainingMs=$holdRemainingMs, "
                "resistance=$resistance, "
                "telemetryRunId=$telemetryRunId, "
                "telemetrySequence=$telemetrySequence"
                ")";
    }
}