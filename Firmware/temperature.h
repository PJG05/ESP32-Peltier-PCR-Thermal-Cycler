#ifndef TEMPERATURE_H
#define TEMPERATURE_H

#include <Arduino.h>

//======================================================
// Initialization
//======================================================

void temperatureInit();

//======================================================
// Update Sensor
//======================================================

void temperatureUpdate();

//======================================================
// Getters
//======================================================

float getTemperature();

float getResistance();

bool sensorConnected();

uint8_t getSensorFault();

#endif