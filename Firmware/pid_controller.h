#ifndef PID_CONTROLLER_H
#define PID_CONTROLLER_H

#include <Arduino.h>

//======================================================
// THERMAL MODES
//======================================================

enum ThermalMode
{
    MODE_FAST_RAMP,
    MODE_APPROACH,
    MODE_HOLD
};


//======================================================
// INITIALIZATION
//======================================================

void pidInit();

void resetPID();


//======================================================
// TARGET
//======================================================

void setTargetTemperature(float target);

float getTargetTemperature();


//======================================================
// MAIN CONTROLLER
//======================================================

int computePID(float currentTemperature);


//======================================================
// MODE
//======================================================

ThermalMode getThermalMode();


//======================================================
// FAR ZONE
//======================================================

void setFarZoneThreshold(float threshold);

float getFarZoneThreshold();


//======================================================
// PID TUNINGS
//======================================================

void setPIDTunings(
    float kp,
    float ki,
    float kd
);

void getPIDTunings(
    float &kp,
    float &ki,
    float &kd
);


//======================================================
// OUTPUT
//======================================================

int getPIDOutput();

#endif