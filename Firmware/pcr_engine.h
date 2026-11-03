#ifndef PCR_ENGINE_H
#define PCR_ENGINE_H

#include <Arduino.h>

//======================================================
// PCR State Machine
//
// PCR sequence:
//
// IDLE
//
//   ↓
//
// INITIAL_HEATING
//   Initial denaturation ramp
//
//   ↓
//
// INITIAL_HOLD
//   Initial denaturation hold
//
//   ↓
//
// PCR cycling:
//
//   STAGE_HEATING
//       ↓
//   STAGE_HOLD
//       ↓
//   NEXT_STAGE
//
//   After all stages:
//
//   NEXT_CYCLE
//
//   Repeat until all cycles complete.
//
//   ↓
//
// FINAL_HEATING
//   Final extension ramp
//
//   ↓
//
// FINAL_HOLD
//   Final extension hold
//
//   ↓
//
// STORAGE_HOLD
//   Active temperature control at DEFAULT_HOLD_TEMP
//   (typically 4 C) until user presses STOP.
//
//======================================================

enum PCRState
{
    //--------------------------------------------------
    // System idle
    //--------------------------------------------------

    PCR_IDLE,

    //--------------------------------------------------
    // Initial Denaturation
    //--------------------------------------------------

    PCR_INITIAL_HEATING,

    PCR_INITIAL_HOLD,

    //--------------------------------------------------
    // PCR Cycle Stages
    //
    // Used for:
    //
    // Denaturation
    // Annealing
    // Extension
    //
    //--------------------------------------------------

    PCR_STAGE_HEATING,

    PCR_STAGE_HOLD,

    //--------------------------------------------------
    // Stage / Cycle Transition
    //--------------------------------------------------

    PCR_NEXT_STAGE,

    PCR_NEXT_CYCLE,

    //--------------------------------------------------
    // Final Extension
    //--------------------------------------------------

    PCR_FINAL_HEATING,

    PCR_FINAL_HOLD,

    //--------------------------------------------------
    // Final Storage Hold
    //
    // After PCR completes, actively maintain
    // DEFAULT_HOLD_TEMP (normally 4 C).
    //
    // Unlike PCR_FINISHED, TEC control remains active.
    //
    // The machine remains here until the user presses
    // STOP.
    //--------------------------------------------------

    PCR_STORAGE_HOLD,

    //--------------------------------------------------
    // PCR Finished
    //
    // Reserved for a fully finished/inactive state.
    //--------------------------------------------------

    PCR_FINISHED,

    //--------------------------------------------------
    // PCR Paused
    //--------------------------------------------------

    PCR_PAUSED,

    //--------------------------------------------------
    // PCR Error / Safety Stop
    //--------------------------------------------------

    PCR_ERROR
};


//======================================================
// Initialization
//======================================================

void pcrInit();


//======================================================
// PCR Control
//======================================================

//------------------------------------------------------
// Start the currently loaded PCR program.
//
// Sequence begins with initial denaturation.
//------------------------------------------------------

void pcrStart();


//------------------------------------------------------
// Stop the PCR program.
//
// Stops TEC output and returns the PCR engine to IDLE.
//------------------------------------------------------

void pcrStop();


//------------------------------------------------------
// Pause the current PCR program.
//
// TEC output is stopped while paused.
//------------------------------------------------------

void pcrPause();


//------------------------------------------------------
// Resume a paused PCR program.
//
// Returns to the state active before the pause.
//------------------------------------------------------

void pcrResume();


//======================================================
// PCR Engine Update
//
// Must be called continuously from the main firmware
// loop.
//
// Handles:
//
// - Temperature control
// - PCR state transitions
// - Initial denaturation
// - PCR cycling
// - Denaturation
// - Annealing
// - Extension
// - Final extension
// - Final 4 C storage hold
// - Valid hold-time tracking
// - Safety handling
//
//======================================================

void pcrUpdate();


//======================================================
// PCR Status
//======================================================

//------------------------------------------------------
// Returns true while a PCR program is active.
//------------------------------------------------------

bool pcrRunning();


//------------------------------------------------------
// Returns true when PCR is paused.
//------------------------------------------------------

bool pcrPaused();


//------------------------------------------------------
// Returns the current PCR state.
//------------------------------------------------------

PCRState getPCRState();


//------------------------------------------------------
// Returns human-readable name of current PCR state.
//
// Examples:
//
// "INITIAL_HEATING"
// "INITIAL_HOLD"
// "STAGE_HEATING"
// "STAGE_HOLD"
// "FINAL_HOLD"
// "STORAGE_HOLD"
// "PAUSED"
// "ERROR"
//
//======================================================

const char* getStateName();


#endif