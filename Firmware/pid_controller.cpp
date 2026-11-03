#include "pid_controller.h"
#include "config.h"

#include <Arduino.h>
#include <math.h>

//======================================================
// PCR Thermal Controller
//
// Commercial Bang-Bang Controller
//
// FAST RAMP
//      |
//      V
// APPROACH
//      |
//      V
// HOLD
//
// No PID
// No Integral
// No Derivative
//======================================================


//======================================================
// Internal Variables
//======================================================

static ThermalMode mode = MODE_FAST_RAMP;

static float targetTemperature = 25.0f;

static int pwmOutput = 0;


//======================================================
// User Adjustable Parameters
//======================================================

// Distance from target

static float farZone = 5.0f;

static const float APPROACH_ZONE = 1.0f;

static const float HOLD_ZONE = 0.30f;


//======================================================
// PWM Levels
//======================================================

// Heating

static const int HEAT_FULL = 255;

static const int HEAT_APPROACH = 235;

static const int HEAT_TRIM = 205;


//======================================================
// Cooling
//======================================================

static const int COOL_FULL = -255;

static const int COOL_APPROACH = -255;

static const int COOL_TRIM = -180;


//======================================================
// WiFi Compatibility
//======================================================

static float kp = 0;
static float ki = 0;
static float kd = 0;


//======================================================
// Initialization
//======================================================

void pidInit()
{
    mode = MODE_FAST_RAMP;

    targetTemperature = 25.0f;

    pwmOutput = 0;

    Serial.println("--------------------------------");
    Serial.println("Bang Bang Controller");
    Serial.println("--------------------------------");
}


//======================================================
// Reset
//======================================================

void resetPID()
{
    //--------------------------------------------------
    // IMPORTANT
    //
    // A reset always starts a fresh thermal approach.
    //
    // This is required when:
    //
    // Initial Denaturation = 90°C
    // Denaturation         = 90°C
    //
    // Even though the target value is identical,
    // the second stage must NOT inherit HOLD mode
    // from the previous stage.
    //--------------------------------------------------

    mode = MODE_FAST_RAMP;

    pwmOutput = 0;
}


//======================================================
// Target
//======================================================

void setTargetTemperature(float target)
{
    //--------------------------------------------------
    // If the target is exactly the same, do NOT
    // automatically reset the controller.
    //
    // This prevents repeated calls during HOLD from
    // re-arming FAST RAMP.
    //--------------------------------------------------

    if(fabs(target - targetTemperature) < 0.01f)
        return;


    targetTemperature = target;

    pwmOutput = 0;

    mode = MODE_FAST_RAMP;


    Serial.println("--------------------------------");

    Serial.print("New Target : ");

    Serial.println(targetTemperature);

    Serial.println("--------------------------------");
}


//======================================================
// Get Target
//======================================================

float getTargetTemperature()
{
    return targetTemperature;
}


//======================================================
// Thermal Mode
//======================================================

ThermalMode getThermalMode()
{
    return mode;
}


//======================================================
// PID Compatibility
//======================================================

void setPIDTunings(
    float p,
    float i,
    float d)
{
    kp = p;

    ki = i;

    kd = d;
}


void getPIDTunings(
    float &p,
    float &i,
    float &d)
{
    p = kp;

    i = ki;

    d = kd;
}


//======================================================
// Far Zone
//======================================================

void setFarZoneThreshold(float threshold)
{
    if(threshold < 1.0f)
        threshold = 1.0f;

    if(threshold > 10.0f)
        threshold = 10.0f;

    farZone = threshold;
}


float getFarZoneThreshold()
{
    return farZone;
}


//======================================================
// Output
//======================================================

int getPIDOutput()
{
    return pwmOutput;
}


//======================================================
// Controller
//======================================================

int computePID(float currentTemperature)
{
    float error =
        targetTemperature - currentTemperature;

    float absError =
        fabs(error);


    //==================================================
    // FAST RAMP
    //==================================================

    if(mode == MODE_FAST_RAMP)
    {
        //--------------------------------------------------
        // Far away from target
        //--------------------------------------------------

        if(absError > farZone)
        {
            if(error > 0)
            {
                // Need heating
                pwmOutput = HEAT_FULL;
            }
            else
            {
                // Need cooling
                pwmOutput = COOL_FULL;
            }

            return pwmOutput;
        }


        //--------------------------------------------------
        // We are now close enough to start approaching
        //--------------------------------------------------

        mode = MODE_APPROACH;

        Serial.println("Entering APPROACH");
    }


    //==================================================
    // APPROACH
    //==================================================

    if(mode == MODE_APPROACH)
    {
        //--------------------------------------------------
        // Very close to target
        //--------------------------------------------------

        if(absError <= HOLD_ZONE)
        {
            mode = MODE_HOLD;

            Serial.println("Entering HOLD");
        }

        else
        {
            //--------------------------------------------------
            // Heating
            //--------------------------------------------------

            if(error > 0)
            {
                if(absError > APPROACH_ZONE)
                {
                    pwmOutput = HEAT_APPROACH;
                }
                else
                {
                    pwmOutput = HEAT_TRIM;
                }
            }

            //--------------------------------------------------
            // Cooling
            //--------------------------------------------------

            else
            {
                if(absError > APPROACH_ZONE)
                {
                    pwmOutput = COOL_APPROACH;
                }
                else
                {
                    pwmOutput = COOL_TRIM;
                }
            }

            return pwmOutput;
        }
    }


    //==================================================
    // HOLD
    //==================================================

    if(mode == MODE_HOLD)
    {
        //--------------------------------------------------
        // Too cold
        //--------------------------------------------------

        if(error > 0.40f)
        {
            pwmOutput = HEAT_TRIM;
        }


        //--------------------------------------------------
        // Slightly cold
        //--------------------------------------------------

        else if(error > 0.10f)
        {
            pwmOutput = HEAT_TRIM - 20;
        }


        //--------------------------------------------------
        // Good zone
        //--------------------------------------------------

        else if(error >= -0.50f)
        {
            if(targetTemperature <= 6.0f)
            {
                //--------------------------------------------------
                // Storage hold around 4°C
                //--------------------------------------------------

                pwmOutput = -70;
            }

            else
            {
                //--------------------------------------------------
                // Normal PCR temperatures
                //--------------------------------------------------

                pwmOutput = 70;
            }
        }


        //--------------------------------------------------
        // Slight overshoot
        //--------------------------------------------------

        else if(error >= -1.00f)
        {
            pwmOutput = 0;
        }


        //--------------------------------------------------
        // Large overshoot
        //--------------------------------------------------

        else
        {
            if(targetTemperature <= 6.0f)
            {
                //--------------------------------------------------
                // Storage hold needs stronger cooling
                //--------------------------------------------------

                pwmOutput = -180;
            }

            else
            {
                if(targetTemperature <= 5.0f)
                {
                    pwmOutput = COOL_FULL;
                }
                else
                {
                    pwmOutput = COOL_TRIM;
                }
            }
        }
    }


    //==================================================
    // Debug
    //==================================================

    Serial.print("Mode : ");

    switch(mode)
    {
        case MODE_FAST_RAMP:

            Serial.print("RAMP");

            break;


        case MODE_APPROACH:

            Serial.print("APPROACH");

            break;


        case MODE_HOLD:

            Serial.print("HOLD");

            break;
    }


    Serial.print("  Target: ");

    Serial.print(targetTemperature);


    Serial.print("  Temp: ");

    Serial.print(currentTemperature);


    Serial.print("  Error: ");

    Serial.print(error);


    Serial.print("  PWM: ");

    Serial.println(pwmOutput);


    return pwmOutput;
}