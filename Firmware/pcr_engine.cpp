#include "pcr_engine.h"
#include "config.h"
#include "protocol.h"
#include "pid_controller.h"
#include "tec_driver.h"
#include "temperature.h"
#include "status.h"

#include <math.h>

//======================================================
// Internal State
//======================================================

static PCRState currentState = PCR_IDLE;
static PCRState stateBeforePause = PCR_IDLE;

static uint8_t currentCycle = 0;
static uint8_t currentStage = 0;

//======================================================
// Stability Detection
//======================================================

static bool stabilityTimerRunning = false;
static unsigned long stableStartTime = 0;

// Hysteresis prevents rapid oscillation around the target.
static bool insideStableBand = false;

//======================================================
// Hold Timer
//
// IMPORTANT:
//
// This timer belongs entirely to the ESP32.
//
// Wi-Fi, Flutter, HTTP requests and status polling have
// NO authority over this timer.
//
// holdElapsed = actual VALID hold time accumulated
// while the temperature is considered stable.
//======================================================

static unsigned long holdElapsed = 0;
static unsigned long lastHoldUpdate = 0;

//======================================================
// Forward Declarations
//======================================================

static void goToState(PCRState state);
static void applyTemperatureTarget(float target);
static void startStageHeating();

static bool isTemperatureStable(
    float current,
    float target
);

static bool isReadyForHold(
    float current,
    float target
);

static bool updateHoldTimer(
    float current,
    float target,
    unsigned long required
);

static void startHoldTimer();

static void updateStatusFields();

//======================================================
// Init
//======================================================

void pcrInit()
{
    currentState = PCR_IDLE;
    stateBeforePause = PCR_IDLE;

    currentCycle = 0;
    currentStage = 0;

    stabilityTimerRunning = false;
    stableStartTime = 0;

    holdElapsed = 0;
    lastHoldUpdate = millis();

    insideStableBand = false;

    stopTEC();
    resetPID();

    Serial.println("--------------------------------");
    Serial.println("PCR Engine Initialized");
    Serial.println("--------------------------------");
}

//======================================================
// Start
//======================================================

void pcrStart()
{
    PCRProgram &program = getProgram();

    if(program.stageCount == 0)
    {
        Serial.println("No PCR Program");
        return;
    }

    if(!sensorConnected())
    {
        Serial.println("Sensor Missing");
        return;
    }

    currentCycle = 1;
    currentStage = 0;

    resetPID();

    holdElapsed = 0;
    lastHoldUpdate = millis();

    stabilityTimerRunning = false;
    stableStartTime = 0;

    insideStableBand = false;

    auto &status = getStatus();

    status.running = true;
    status.finished = false;
    status.paused = false;

    applyTemperatureTarget(program.initialTemp);

    goToState(PCR_INITIAL_HEATING);

    updateStatusFields();
}

//======================================================
// Stop
//======================================================

void pcrStop()
{
    stopTEC();

    resetPID();

    resetStatus();

    currentState = PCR_IDLE;

    currentCycle = 0;
    currentStage = 0;

    stabilityTimerRunning = false;
    stableStartTime = 0;

    insideStableBand = false;

    holdElapsed = 0;
    lastHoldUpdate = millis();
}

//======================================================
// Pause
//======================================================

void pcrPause()
{
    if(currentState == PCR_IDLE)
        return;

    //--------------------------------------------------
    // IMPORTANT:
    //
    // If we are currently in a hold, account for the
    // elapsed valid hold time BEFORE stopping.
    //
    // This prevents losing up to one scheduler interval
    // when the user presses PAUSE.
    //--------------------------------------------------

    if(currentState == PCR_INITIAL_HOLD)
    {
        PCRProgram &program = getProgram();

        updateHoldTimer(
            getTemperature(),
            program.initialTemp,
            program.initialHold * 1000UL
        );
    }
    else if(currentState == PCR_STAGE_HOLD)
    {
        PCRProgram &program = getProgram();

        updateHoldTimer(
            getTemperature(),
            program.stages[currentStage].temperature,
            program.stages[currentStage].holdTime * 1000UL
        );
    }
    else if(currentState == PCR_FINAL_HOLD)
    {
        PCRProgram &program = getProgram();

        updateHoldTimer(
            getTemperature(),
            program.finalTemp,
            program.finalHold * 1000UL
        );
    }

    stateBeforePause = currentState;

    currentState = PCR_PAUSED;

    stopTEC();

    getStatus().paused = true;

    updateStatusFields();
}

//======================================================
// Resume
//======================================================

void pcrResume()
{
    if(currentState != PCR_PAUSED)
        return;

    //--------------------------------------------------
    // Restart the hold timing reference.
    //
    // Time spent paused is NEVER counted as PCR hold
    // time.
    //--------------------------------------------------

    lastHoldUpdate = millis();

    currentState = stateBeforePause;

    getStatus().paused = false;

    updateStatusFields();
}

//======================================================
// PCR Update
//======================================================

void pcrUpdate()
{
    auto &status = getStatus();

    float currentTemp = getTemperature();

    //--------------------------------------------------
    // Safety
    //--------------------------------------------------

    if(currentState != PCR_IDLE &&
       currentState != PCR_ERROR)
    {
        if(!sensorConnected() ||
           currentTemp > MAX_SAFE_TEMP ||
           currentTemp < MIN_SAFE_TEMP ||
           status.emergencyStop)
        {
            Serial.println("PCR SAFETY TRIP");

            stopTEC();

            resetPID();

            currentState = PCR_ERROR;

            status.running = false;

            return;
        }
    }

    //--------------------------------------------------
    // Idle
    //--------------------------------------------------

    if(currentState == PCR_IDLE)
    {
        stopTEC();

        updateStatusFields();

        return;
    }

    //--------------------------------------------------
    // Paused
    //--------------------------------------------------

    if(currentState == PCR_PAUSED)
    {
        stopTEC();

        updateStatusFields();

        return;
    }

    //--------------------------------------------------
    // Error
    //--------------------------------------------------

    if(currentState == PCR_ERROR)
    {
        stopTEC();

        updateStatusFields();

        return;
    }

    //--------------------------------------------------
    // Finished
    //--------------------------------------------------

    if(currentState == PCR_FINISHED)
    {
        updateStatusFields();

        return;
    }

    //--------------------------------------------------
    // Thermal Controller
    //--------------------------------------------------

    int pwm = computePID(currentTemp);

    setTECPower(pwm);

    //--------------------------------------------------
    // Debug
    //--------------------------------------------------

    Serial.print("Temp=");
    Serial.print(currentTemp);

    Serial.print(" Target=");
    Serial.print(getTargetTemperature());

    Serial.print(" PWM=");
    Serial.print(pwm);

    Serial.print(" State=");
    Serial.println(getStateName());

    //--------------------------------------------------
    // PCR Program
    //--------------------------------------------------

    PCRProgram &program = getProgram();

    unsigned long now = millis();

    switch(currentState)
{
    //==================================================
    // Initial Heating
    //==================================================

    case PCR_INITIAL_HEATING:
    {
        float target = program.initialTemp;

        //--------------------------------------------------
        // START HOLD IMMEDIATELY when temperature enters
        // the +/-0.5 C target window.
        //
        // Example:
        //
        // Target = 90 C
        //
        // 88.9 -> no
        // 89.4 -> no
        // 89.5 -> HOLD STARTS
        // 90.0 -> HOLD
        // 90.4 -> HOLD
        //
        // No STABLE_TIME_MS waiting.
        //--------------------------------------------------

        if(fabsf(currentTemp - target) <= TEMP_TOLERANCE)
        {
            startHoldTimer();

            goToState(PCR_INITIAL_HOLD);

            Serial.println();
            Serial.println("================================");
            Serial.println("INITIAL DENATURATION TARGET REACHED");
            Serial.print("Target: ");
            Serial.print(target);
            Serial.println(" C");

            Serial.print("Temperature: ");
            Serial.print(currentTemp);
            Serial.println(" C");

            Serial.println("Initial Hold Timer STARTED");
            Serial.println("================================");
        }

        break;
    }


    //==================================================
    // Initial Hold
    //==================================================

    case PCR_INITIAL_HOLD:

        if(updateHoldTimer(
            currentTemp,
            program.initialTemp,
            program.initialHold * 1000UL))
        {
            currentStage = 0;

            startStageHeating();
        }

        break;


    //==================================================
    // Stage Heating
    //==================================================

    case PCR_STAGE_HEATING:
    {
        float target =
            program.stages[currentStage].temperature;

        //--------------------------------------------------
        // START HOLD IMMEDIATELY when temperature enters
        // +/-0.5 C of the current stage target.
        //
        // This applies to:
        //
        // Stage 0 = Denaturation
        // Stage 1 = Annealing
        // Stage 2 = Extension
        // ...and any additional stages.
        //--------------------------------------------------

        if(fabsf(currentTemp - target) <= TEMP_TOLERANCE)
        {
            startHoldTimer();

            goToState(PCR_STAGE_HOLD);

            Serial.println();
            Serial.println("================================");

            Serial.print("STAGE TARGET REACHED: ");
            Serial.println(
                program.stages[currentStage].temperature
            );

            Serial.print("Stage: ");
            Serial.print(currentStage + 1);

            Serial.print("  Temperature: ");
            Serial.print(currentTemp);

            Serial.println(" C");

            Serial.println("Stage Hold Timer STARTED");

            Serial.println("================================");
        }

        break;
    }


    //==================================================
    // Stage Hold
    //==================================================

    case PCR_STAGE_HOLD:

        if(updateHoldTimer(
            currentTemp,
            program.stages[currentStage].temperature,
            program.stages[currentStage].holdTime * 1000UL))
        {
            goToState(PCR_NEXT_STAGE);
        }

        break;


    //==================================================
    // Next Stage
    //==================================================

    case PCR_NEXT_STAGE:

        currentStage++;

        if(currentStage < program.stageCount)
        {
            startStageHeating();
        }
        else
        {
            goToState(PCR_NEXT_CYCLE);
        }

        break;


    //==================================================
    // Next Cycle
    //==================================================

    case PCR_NEXT_CYCLE:

        if(currentCycle < program.cycles)
        {
            currentCycle++;

            currentStage = 0;

            startStageHeating();
        }
        else
        {
            applyTemperatureTarget(
                program.finalTemp
            );

            goToState(PCR_FINAL_HEATING);
        }

        break;


    //==================================================
    // Final Heating
    //==================================================

    case PCR_FINAL_HEATING:
    {
        float target = program.finalTemp;

        //--------------------------------------------------
        // START FINAL EXTENSION HOLD IMMEDIATELY when
        // temperature enters +/-0.5 C of final target.
        //--------------------------------------------------

        if(fabsf(currentTemp - target) <= TEMP_TOLERANCE)
        {
            startHoldTimer();

            goToState(PCR_FINAL_HOLD);

            Serial.println();
            Serial.println("================================");
            Serial.println("FINAL EXTENSION TARGET REACHED");

            Serial.print("Target: ");
            Serial.print(target);

            Serial.println(" C");

            Serial.print("Temperature: ");
            Serial.print(currentTemp);

            Serial.println(" C");

            Serial.println("Final Hold Timer STARTED");
            Serial.println("================================");
        }

        break;
    }


    //==================================================
    // Final Hold
    //==================================================

    case PCR_FINAL_HOLD:

        if(updateHoldTimer(
            currentTemp,
            program.finalTemp,
            program.finalHold * 1000UL))
        {
            applyTemperatureTarget(
                DEFAULT_HOLD_TEMP
            );

            goToState(PCR_STORAGE_HOLD);
        }

        break;


    //==================================================
    // Storage Hold
    //==================================================

    case PCR_STORAGE_HOLD:

        // Maintain 4°C indefinitely.
        applyTemperatureTarget(
            DEFAULT_HOLD_TEMP
        );

        break;


    //==================================================
    // Default
    //==================================================

    default:

        break;
}

    updateStatusFields();
}

//======================================================
// Status
//======================================================

bool pcrRunning()
{
    return getStatus().running;
}

bool pcrPaused()
{
    return currentState == PCR_PAUSED;
}

PCRState getPCRState()
{
    return currentState;
}

//======================================================
// State Name
//======================================================

const char* getStateName()
{
    switch(currentState)
    {
        case PCR_IDLE:
            return "IDLE";

        case PCR_INITIAL_HEATING:
            return "INITIAL_HEATING";

        case PCR_INITIAL_HOLD:
            return "INITIAL_HOLD";

        case PCR_STAGE_HEATING:
            return "STAGE_HEATING";

        case PCR_STAGE_HOLD:
            return "STAGE_HOLD";

        case PCR_NEXT_STAGE:
            return "NEXT_STAGE";

        case PCR_NEXT_CYCLE:
            return "NEXT_CYCLE";

        case PCR_FINAL_HEATING:
            return "FINAL_HEATING";

        case PCR_FINAL_HOLD:
            return "FINAL_HOLD";

        case PCR_STORAGE_HOLD:
            return "STORAGE_HOLD";

        case PCR_PAUSED:
            return "PAUSED";

        case PCR_ERROR:
            return "ERROR";

        case PCR_FINISHED:
            return "FINISHED";

        default:
            return "UNKNOWN";
    }
}

//======================================================
// Change State
//======================================================

static void goToState(PCRState state)
{
    currentState = state;

    stabilityTimerRunning = false;

    insideStableBand = false;

    stableStartTime = 0;

    getStatus().state = getStateName();
}

//======================================================
// Apply Target
//======================================================

static void applyTemperatureTarget(float target)
{
    insideStableBand = false;

    setTargetTemperature(target);

    getStatus().targetTemperature = target;
}

//======================================================
// Start Next Stage
//======================================================

//======================================================
// Start Next Stage
//======================================================

static void startStageHeating()
{
    PCRProgram &program = getProgram();

    //--------------------------------------------------
    // A new stage gets a completely fresh hold timer.
    //--------------------------------------------------

    holdElapsed = 0;

    lastHoldUpdate = millis();


    //--------------------------------------------------
    // IMPORTANT:
    //
    // Every new PCR stage gets a fresh thermal-control
    // ramp.
    //
    // This is critical when two consecutive stages have
    // the SAME target temperature.
    //
    // Example:
    //
    // Initial Denaturation = 90°C
    // Denaturation         = 90°C
    //
    // The target value does not change, so
    // setTargetTemperature(90) would normally ignore
    // the request.
    //
    // resetPID() forces:
    //
    // MODE_FAST_RAMP
    // PWM = 0
    //
    // Therefore if the temperature has fallen to 81°C,
    // the controller sees:
    //
    // Target = 90°C
    // Temp   = 81°C
    // Error  = +9°C
    //
    // and immediately begins heating again.
    //--------------------------------------------------

    resetPID();


    //--------------------------------------------------
    // Apply the target temperature for this stage.
    //--------------------------------------------------

    applyTemperatureTarget(
        program.stages[currentStage].temperature);


    //--------------------------------------------------
    // Enter stage heating.
    //--------------------------------------------------

    goToState(PCR_STAGE_HEATING);
}

//======================================================
// Stability
//======================================================

static bool isTemperatureStable(
    float current,
    float target)
{
    float error = fabsf(current - target);

    //--------------------------------------------------
    // Enter stable band
    //--------------------------------------------------

    if(!insideStableBand)
    {
        if(error <= TEMP_TOLERANCE)
        {
            insideStableBand = true;
        }
    }

    //--------------------------------------------------
    // Leave only after larger drift.
    //--------------------------------------------------

    else
    {
        if(error > (TEMP_TOLERANCE + 1.0f))
        {
            insideStableBand = false;
        }
    }

    return insideStableBand;
}
//======================================================
// Ready For Hold
//======================================================

static bool isReadyForHold(
    float current,
    float target)
{
    //--------------------------------------------------
    // Temperature must first be inside the normal
    // stability band.
    //--------------------------------------------------

    if(!isTemperatureStable(
        current,
        target))
    {
        return false;
    }


    //--------------------------------------------------
    // ANNEALING PROTECTION
    //
    // currentStage == 1 means:
    //
    // Stage 1 = Annealing
    //
    // Do NOT allow the hold timer to start while
    // the thermal controller is still actively
    // cooling.
    //
    // Example:
    //
    // Target = 60°C
    // Temp   = 60°C
    // PWM    = -25
    //
    // Previously:
    //     HOLD starts
    //
    // Now:
    //     HOLD does NOT start.
    //
    // The controller must first stop cooling.
    //--------------------------------------------------

    if(currentState == PCR_STAGE_HEATING &&
       currentStage == 1)
    {
        if(getPIDOutput() < 0)
        {
            return false;
        }
    }


    return true;
}
//======================================================
// Start Hold Timer
//======================================================

static void startHoldTimer()
{
    //--------------------------------------------------
    // IMPORTANT:
    //
    // Hold starts HERE.
    //
    // This is after the temperature has already remained
    // stable for STABLE_TIME_MS.
    //--------------------------------------------------

    holdElapsed = 0;

    lastHoldUpdate = millis();
}

//======================================================
// Hold Counting
//======================================================

static bool updateHoldTimer(
    float current,
    float target,
    unsigned long required)
{
    unsigned long now = millis();

    //--------------------------------------------------
    // Time elapsed since the hold started.
    //
    // Once HOLD starts, the programmed hold time runs
    // continuously. Temperature fluctuations do NOT
    // reset or pause the timer.
    //--------------------------------------------------

    unsigned long delta = now - lastHoldUpdate;

    //--------------------------------------------------
    // Prevent timer from exceeding the programmed
    // hold duration.
    //--------------------------------------------------

    if(delta >= required - holdElapsed)
    {
        holdElapsed = required;
    }
    else
    {
        holdElapsed += delta;
    }

    //--------------------------------------------------
    // Update timestamp for the next calculation.
    //--------------------------------------------------

    lastHoldUpdate = now;

    return holdElapsed >= required;
}

//======================================================
// Update Status
//======================================================

static void updateStatusFields()
{
    auto &status = getStatus();

    PCRProgram &program = getProgram();

    status.currentTemperature = getTemperature();

    status.targetTemperature = getTargetTemperature();

    status.heater = heaterRunning();

    status.cooler = coolerRunning();

    status.pwm = getPWMOutput();

    status.state = getStateName();

    status.cycle = currentCycle;

    status.totalCycles = program.cycles;

    //--------------------------------------------------
    // Stage
    //--------------------------------------------------

    if(currentState == PCR_STAGE_HEATING ||
       currentState == PCR_STAGE_HOLD)
    {
        status.stage = currentStage + 1;
    }
    else
    {
        status.stage = 0;
    }

    status.totalStages = program.stageCount;

    //--------------------------------------------------
    // Stage Name
    //--------------------------------------------------

    switch(currentState)
    {
        case PCR_INITIAL_HEATING:
        case PCR_INITIAL_HOLD:

            status.stageName = "Initial Denaturation";

            break;

        case PCR_STAGE_HEATING:
        case PCR_STAGE_HOLD:

            if(currentStage == 0)
                status.stageName = "Denaturation";

            else if(currentStage == 1)
                status.stageName = "Annealing";

            else
                status.stageName = "Extension";

            break;

        case PCR_FINAL_HEATING:
        case PCR_FINAL_HOLD:

            status.stageName = "Final Extension";

            break;

        case PCR_STORAGE_HOLD:

            status.stageName = "Final Hold";

            break;

        case PCR_PAUSED:

            status.stageName = "Paused";

            break;

        case PCR_ERROR:

            status.stageName = "Error";

            break;

        default:

            status.stageName = "Idle";

            break;
    }

    //--------------------------------------------------
    // Phase
    //--------------------------------------------------

    switch(currentState)
    {
        case PCR_INITIAL_HOLD:
        case PCR_STAGE_HOLD:
        case PCR_FINAL_HOLD:
        case PCR_STORAGE_HOLD:

            status.phase = "Holding";

            break;

        case PCR_INITIAL_HEATING:
        case PCR_STAGE_HEATING:
        case PCR_FINAL_HEATING:

            if(getTargetTemperature() > getTemperature())
                status.phase = "Heating";
            else
                status.phase = "Cooling";

            break;

        default:

            status.phase = "";

            break;
    }

    //--------------------------------------------------
    // Hold Remaining
    //
    // Internal representation remains milliseconds.
    //--------------------------------------------------

    unsigned long required = 0;

    if(currentState == PCR_INITIAL_HOLD)
    {
        required = program.initialHold * 1000UL;
    }
    else if(currentState == PCR_STAGE_HOLD)
    {
        required =
            program.stages[currentStage].holdTime * 1000UL;
    }
    else if(currentState == PCR_FINAL_HOLD)
    {
        required =
            program.finalHold * 1000UL;
    }

    //--------------------------------------------------
    // Never allow remaining time to become negative or
    // wrap around because of unsigned arithmetic.
    //--------------------------------------------------

    if(required > holdElapsed)
        status.holdRemaining = required - holdElapsed;
    else
        status.holdRemaining = 0;

    //--------------------------------------------------
    // Running Flags
    //--------------------------------------------------

    status.running =
        !(currentState == PCR_IDLE ||
          currentState == PCR_ERROR ||
          currentState == PCR_FINISHED);

    status.finished =
        (currentState == PCR_FINISHED);
}