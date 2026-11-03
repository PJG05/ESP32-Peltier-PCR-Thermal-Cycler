#ifndef TEC_DRIVER_H
#define TEC_DRIVER_H

#include <Arduino.h>

//======================================================
// Initialization
//======================================================

void tecInit();

//======================================================
// TEC Control
//======================================================

void heaterPWM(uint8_t pwm);

void coolerPWM(uint8_t pwm);

void stopTEC();

//======================================================
// Automatic Power Control
//======================================================

void setTECPower(int pwm);

//======================================================
// Status
//======================================================

bool heaterRunning();

bool coolerRunning();

uint8_t getPWMOutput();

#endif