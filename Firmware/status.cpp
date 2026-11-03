#include "status.h"

//======================================================
// Internal Object
//======================================================

static SystemStatus systemStatus;

//======================================================
// Initialization
//======================================================

void statusInit()
{
    resetStatus();

    Serial.println("--------------------------------");
    Serial.println("Status Module Initialized");
    Serial.println("--------------------------------");
}

//======================================================
// Getter
//======================================================

SystemStatus& getStatus()
{
    return systemStatus;
}

//======================================================
// Reset
//======================================================

void resetStatus()
{
    //--------------------------------------------------
    // Temperature
    //--------------------------------------------------

    systemStatus.currentTemperature = 25.0f;
    systemStatus.targetTemperature = 25.0f;
    systemStatus.resistance = 1000.0f;

    //--------------------------------------------------
    // TEC
    //--------------------------------------------------

    systemStatus.pwm = 0;

    systemStatus.heater = false;
    systemStatus.cooler = false;

    //--------------------------------------------------
    // PCR
    //--------------------------------------------------

    systemStatus.running = false;
    systemStatus.paused = false;
    systemStatus.finished = false;

    systemStatus.cycle = 0;
    systemStatus.totalCycles = 0;

    systemStatus.stage = 0;
    systemStatus.totalStages = 0;

    systemStatus.holdRemaining = 0;
    systemStatus.rampTimeMs = 0;

    systemStatus.stageName = "Idle";
    systemStatus.phase = "Idle";
    systemStatus.state = "IDLE";

    //--------------------------------------------------
    // Safety
    //--------------------------------------------------

    systemStatus.sensorConnected = true;
    systemStatus.sensorFault = 0;

    systemStatus.emergencyStop = false;
}