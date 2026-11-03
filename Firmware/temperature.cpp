#include "temperature.h"
#include "config.h"
#include "status.h"

#include <Arduino.h>
#include <Adafruit_MAX31865.h>
#include <math.h>

//======================================================
// MAX31865
//======================================================
//
// IMPORTANT:
//
// This uses the SAME software-SPI constructor as the
// simple Bluetooth PCR sketch that works reliably.
//
// Wiring remains:
//
// CS   -> GPIO 5
// MOSI -> GPIO 23
// MISO -> GPIO 19
// SCK  -> GPIO 18
//
// There is deliberately NO SPI.begin() in this file.
//

Adafruit_MAX31865 thermo(
    MAX31865_CS,
    MAX31865_MOSI,
    MAX31865_MISO,
    MAX31865_SCK
);

//======================================================
// Internal Variables
//======================================================

static float currentTemperature = 25.0f;
static float filteredTemperature = 25.0f;
static float currentResistance = 1000.0f;

static bool sensorOK = true;
static uint8_t faultCode = 0;

//------------------------------------------------------
// Fault debounce
//------------------------------------------------------
//
// A single transient MAX31865 fault must NOT kill
// the PCR.
//
// Only several consecutive bad readings are treated
// as a real sensor failure.
//
// Temperature period = 200 ms
//
// 5 consecutive faults ~= 1 second
//

static uint8_t consecutiveFaults = 0;

static const uint8_t MAX_CONSECUTIVE_FAULTS = 20;

//------------------------------------------------------
// Temperature filter
//------------------------------------------------------

static const float FILTER_ALPHA = 0.20f;

//======================================================
// MAX31865 Fault Description
//======================================================

static void printMAX31865Fault(uint8_t fault)
{
    Serial.print("MAX31865 fault 0x");
    Serial.print(fault, HEX);
    Serial.print(": ");

    bool found = false;

    if (fault & MAX31865_FAULT_HIGHTHRESH)
    {
        Serial.print("RTD HIGH THRESHOLD; ");
        found = true;
    }

    if (fault & MAX31865_FAULT_LOWTHRESH)
    {
        Serial.print("RTD LOW THRESHOLD; ");
        found = true;
    }

    if (fault & MAX31865_FAULT_REFINLOW)
    {
        Serial.print("REFIN- > 0.85 x BIAS; ");
        found = true;
    }

    if (fault & MAX31865_FAULT_REFINHIGH)
    {
        Serial.print("REFIN- < 0.85 x BIAS / FORCE OPEN; ");
        found = true;
    }

    if (fault & MAX31865_FAULT_RTDINLOW)
    {
        Serial.print("RTDIN- < 0.85 x BIAS / FORCE OPEN; ");
        found = true;
    }

    if (fault & MAX31865_FAULT_OVUV)
    {
        Serial.print("UNDER/OVER VOLTAGE; ");
        found = true;
    }

    if (!found)
    {
        Serial.print("UNKNOWN FAULT; ");
    }

    Serial.println();
}

//======================================================
// Register Fault
//======================================================

static void registerFault(uint8_t fault)
{
    faultCode = fault;

    if (consecutiveFaults < 255)
    {
        consecutiveFaults++;
    }

    Serial.print("Temperature sensor fault ");
    Serial.print(consecutiveFaults);
    Serial.print("/");
    Serial.println(MAX_CONSECUTIVE_FAULTS);

    if (fault != 0xFF)
    {
        printMAX31865Fault(fault);
    }
    else
    {
        Serial.println("Invalid temperature/resistance sample");
    }

    //--------------------------------------------------
    // Do NOT immediately kill the PCR.
    //--------------------------------------------------

    if (consecutiveFaults >= MAX_CONSECUTIVE_FAULTS)
    {
    sensorOK = false;

    Serial.println();
    Serial.println("***** SENSOR FAILED FOR MULTIPLE SECONDS *****");
    Serial.println("Stopping PCR");
    Serial.println();
    }
}

//======================================================
// Initialization
//======================================================

void temperatureInit()
{
    //--------------------------------------------------
    // DO NOT call:
    //
    // SPI.begin(...)
    //
    // The MAX31865 object above is using software SPI.
    //--------------------------------------------------

    thermo.begin(MAX31865_2WIRE);

    delay(20);

    thermo.clearFault();

    delay(20);

    thermo.clearFault();

    //--------------------------------------------------
    // Initial values
    //--------------------------------------------------

    currentTemperature = 25.0f;
    filteredTemperature = 25.0f;
    currentResistance = RNOMINAL;

    sensorOK = true;

    faultCode = 0;
    consecutiveFaults = 0;

    //--------------------------------------------------
    // Give MAX31865 a moment after initialization
    //--------------------------------------------------

    delay(500);

    Serial.println("--------------------------------");
    Serial.println("Temperature Module Initialized");
    Serial.println("MAX31865: SOFTWARE SPI");
    Serial.print("CS   : ");
    Serial.println(MAX31865_CS);

    Serial.print("MOSI : ");
    Serial.println(MAX31865_MOSI);

    Serial.print("MISO : ");
    Serial.println(MAX31865_MISO);

    Serial.print("SCK  : ");
    Serial.println(MAX31865_SCK);

    Serial.print("RNOMINAL : ");
    Serial.println(RNOMINAL);

    Serial.print("RREF     : ");
    Serial.println(RREF);

    Serial.println("--------------------------------");
}

//======================================================
// Update Temperature
//======================================================
void temperatureUpdate()
{
//--------------------------------------------------
// Read RTD first
//--------------------------------------------------

uint16_t rawRTD = thermo.readRTD();

Serial.print("RAW RTD = ");
Serial.println(rawRTD);

//--------------------------------------------------
// Read fault generated by THIS conversion
//--------------------------------------------------

uint8_t fault = thermo.readFault();

Serial.print("FAULT = 0x");
Serial.println(fault, HEX);

//--------------------------------------------------
// Handle MAX31865 fault
//--------------------------------------------------

if (fault != 0)
{
    registerFault(fault);
    thermo.clearFault();

    if (!sensorOK)
    {
        auto &status = getStatus();

        status.currentTemperature = filteredTemperature;
        status.resistance = currentResistance;
        status.sensorConnected = false;
        status.sensorFault = faultCode;

        return;
    }
}
//--------------------------------------------------
// Read RTD
//--------------------------------------------------


//--------------------------------------------------
// Detect corrupted SPI transaction
//--------------------------------------------------

if(rawRTD == 0 || rawRTD == 32767)
{
    registerFault(0xFF);

    auto &status = getStatus();

    status.currentTemperature =
        filteredTemperature;

    status.resistance =
        currentResistance;

    status.sensorConnected =
        sensorOK;

    status.sensorFault =
        faultCode;

    return;
}
    //==================================================
    // Convert RTD -> Resistance
    //==================================================

    float ratio =
        (float)rawRTD / 32768.0f;

    float newResistance =
        ratio * RREF;

    //==================================================
    // Convert Resistance -> Temperature
    //==================================================
    delayMicroseconds(100);

    float newTemperature =
    (newResistance - 1000.0f) / 3.85f;

    /* float newTemperature =
        thermo.temperature(
            RNOMINAL,
            RREF
        );  */

    //==================================================
    // Sanity Check
    //==================================================
    //
    // This is NOT a ramp-rate check.
    //
    // 3 C/s, 4 C/s etc. are completely acceptable.
    //
    // We are only rejecting impossible/corrupt values.
    //

    bool validSample = true;

    if (!isfinite(newTemperature))
    {
        validSample = false;
    }

    if (!isfinite(newResistance))
    {
        validSample = false;
    }

    if (newResistance <= 0.0f)
    {
        validSample = false;
    }

    //--------------------------------------------------
    // Broad sensor sanity limits.
    //
    // These are intentionally wider than PCR operating
    // limits. Actual PCR safety limits remain elsewhere.
    //--------------------------------------------------

    if (newTemperature < -200.0f ||
        newTemperature > 250.0f)
    {
        validSample = false;
    }

    if (!validSample)
    {
        registerFault(0xFF);

        auto &status = getStatus();

        status.currentTemperature =
            filteredTemperature;

        status.resistance =
            currentResistance;

        status.sensorConnected =
            sensorOK;

        status.sensorFault =
            faultCode;

        return;
    }

    //==================================================
    // VALID SAMPLE
    //==================================================

    currentTemperature =
        newTemperature;

    currentResistance =
        newResistance;

    //--------------------------------------------------
    // Reset transient fault counter
    //--------------------------------------------------

    consecutiveFaults = 0;

    faultCode = 0;

    sensorOK = true;

    //==================================================
    // Temperature Filtering
    //==================================================

    filteredTemperature =
        FILTER_ALPHA * currentTemperature +
        (1.0f - FILTER_ALPHA) *
        filteredTemperature;

    //==================================================
    // Update System Status
    //==================================================

    auto &status = getStatus();

    status.currentTemperature =
        filteredTemperature;

    status.resistance =
        currentResistance;

    status.sensorConnected =
        true;

    status.sensorFault =
        0;
}

//======================================================
// Get Temperature
//======================================================

float getTemperature()
{
    return filteredTemperature;
}

//======================================================
// Get Resistance
//======================================================

float getResistance()
{
    return currentResistance;
}

//======================================================
// Sensor Connected
//======================================================

bool sensorConnected()
{
    return sensorOK;
}

//======================================================
// Sensor Fault
//======================================================

uint8_t getSensorFault()
{
    return faultCode;
}