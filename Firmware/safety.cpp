#include "safety.h"
#include "config.h"
#include "status.h"
#include "pcr_engine.h"
#include "logger.h"

//======================================================
// Internal State
//======================================================

static PCRState lastObservedState = PCR_IDLE;
static unsigned long stateEnteredAt = 0;

// Prevents spamming the log every SAFETY_UPDATE_PERIOD_MS while a
// fault condition is held/active.
static bool alreadyLoggedTrip = false;

//======================================================
// Initialization
//======================================================

void safetyInit()
{
#if EMERGENCY_STOP_ENABLED
    pinMode(EMERGENCY_STOP_PIN, INPUT_PULLUP);
#endif

    lastObservedState = getPCRState();
    stateEnteredAt = millis();

    Serial.println("--------------------------------");
    Serial.println("Safety Module Initialized");
    Serial.println("--------------------------------");
}

//======================================================
// Update
//======================================================

void safetyUpdate()
{
    PCRState state = getPCRState();

    //--------------------------------------------------
    // Track how long we've been in the current state
    //--------------------------------------------------

    if(state != lastObservedState)
    {
        lastObservedState = state;
        stateEnteredAt = millis();
    }

    //--------------------------------------------------
    // Physical E-Stop Button (wired active-LOW)
    //--------------------------------------------------

#if EMERGENCY_STOP_ENABLED
    if(digitalRead(EMERGENCY_STOP_PIN) == LOW)
    {
        triggerEmergencyStop("Physical E-STOP button pressed");
        return;
    }
#endif

    //--------------------------------------------------
    // Stuck-Heating Detection
    //--------------------------------------------------
    // If we've been trying to reach a heating target for too long
    // without stabilizing, something is wrong with the TEC, PID
    // tuning, or the sensor - flag it rather than heat forever.

    bool inHeatingState =
        (state == PCR_INITIAL_HEATING) ||
        (state == PCR_STAGE_HEATING)   ||
        (state == PCR_FINAL_HEATING);

    if(inHeatingState && (millis() - stateEnteredAt > HEATING_TIMEOUT_MS))
    {
        triggerEmergencyStop("Heating stage timeout - check TEC wiring / PID tuning");
        return;
    }

    //--------------------------------------------------
    // No fault present this cycle
    //--------------------------------------------------

    alreadyLoggedTrip = false;
}

//======================================================
// Manual Control
//======================================================

void triggerEmergencyStop(const String &reason)
{
    SystemStatus &status = getStatus();

    status.emergencyStop = true;

    if(!alreadyLoggedTrip)
    {
        logMessage(LOG_ERROR, "EMERGENCY STOP: " + reason);
        alreadyLoggedTrip = true;
    }
}

void clearEmergencyStop()
{
    getStatus().emergencyStop = false;
    alreadyLoggedTrip = false;

    logMessage(LOG_INFO, "Emergency stop cleared");
}
