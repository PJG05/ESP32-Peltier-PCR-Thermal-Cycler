#ifndef SAFETY_H
#define SAFETY_H

#include <Arduino.h>

//======================================================
// Initialization
//======================================================

void safetyInit();

//======================================================
// Update
//======================================================

// Polls the physical e-stop button and watches for a heating
// stage that's stuck (can't reach target temperature) - both of
// which set SystemStatus.emergencyStop, which pcr_engine.cpp
// already checks on every pcrUpdate().
void safetyUpdate();

//======================================================
// Manual Control
//======================================================

void triggerEmergencyStop(const String &reason);

// Clears the flag only - does NOT resume a run. The PCR engine
// stays in PCR_ERROR until the user explicitly calls pcrStop().
void clearEmergencyStop();

#endif
