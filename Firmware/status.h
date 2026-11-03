#ifndef STATUS_H
#define STATUS_H

#include <Arduino.h>

//======================================================
// System Status
//======================================================

struct SystemStatus
{
    //-----------------------------
    // Temperature
    //-----------------------------

    float currentTemperature;
    float targetTemperature;
    float resistance;

    //-----------------------------
    // TEC
    //-----------------------------

    uint8_t pwm;

    bool heater;
    bool cooler;

    //-----------------------------
    // PCR
    //-----------------------------

    bool running;
    bool paused;
    bool finished;

    uint8_t cycle;
    uint8_t totalCycles;

    uint8_t stage;
    uint8_t totalStages;

    unsigned long holdRemaining;
    unsigned long rampTimeMs;

    String stageName;     // Initial Denaturation
    String phase;         // Heating / Cooling / Holding

    String state; 

    //-----------------------------
    // Safety
    //-----------------------------

    bool sensorConnected;

    uint8_t sensorFault;

    bool emergencyStop;
};

//======================================================
// Initialization
//======================================================

void statusInit();

//======================================================
// Getter
//======================================================

SystemStatus& getStatus();

//======================================================
// Reset
//======================================================

void resetStatus();


#endif