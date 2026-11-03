#include <Arduino.h>

#include "config.h"
#include "temperature.h"
#include "tec_driver.h"
#include "pid_controller.h"
#include "protocol.h"
#include "status.h"
#include "pcr_engine.h"
#include "wifi_server.h"
#include "lcd_display.h"

//======================================================
// PCR Firmware V2
//
// IMPORTANT:
// This main file NEVER calls pcrStart() automatically.
//
// After boot:
//   - sensor initializes
//   - TEC initializes OFF
//   - PID initializes
//   - protocol/program initializes
//   - PCR engine initializes in PCR_IDLE
//   - Wi-Fi server initializes
//   - LCD initializes
//
// The PCR run starts ONLY when your communication layer
// explicitly calls pcrStart(), for example from the app's
// Begin/Start command handled by wifi_server.cpp.
//======================================================

//======================================================
// Scheduler Timestamps
//======================================================

static unsigned long lastTemperatureUpdate = 0;
static unsigned long lastPCRUpdate = 0;
static unsigned long lastWiFiUpdate = 0;
static unsigned long lastLCDUpdate = 0;

//======================================================
// Setup
//======================================================

void setup()
{
    Serial.begin(115200);

    delay(500);

    Serial.println();
    Serial.println("================================");
    Serial.println(FIRMWARE_NAME);
    Serial.print("Version: ");
    Serial.println(FIRMWARE_VERSION);
    Serial.println("================================");

    //--------------------------------------------------
    // Temperature Sensor
    //--------------------------------------------------

    temperatureInit();

    //--------------------------------------------------
    // TEC Driver
    //
    // tecInit() must leave both IBT-4 outputs at zero.
    //--------------------------------------------------

    tecInit();
    stopTEC();

    //--------------------------------------------------
    // PID / Thermal Controller
    //--------------------------------------------------

    pidInit();

    //--------------------------------------------------
    // PCR Program / Protocol
    //
    // This may load a default PCR program into memory,
    // but MUST NOT start the PCR run.
    //--------------------------------------------------

    protocolInit();

    //--------------------------------------------------
    // Status
    //--------------------------------------------------

    statusInit();
    resetStatus();

    //--------------------------------------------------
    // PCR Engine
    //
    // pcrInit() leaves engine in PCR_IDLE.
    //--------------------------------------------------

    pcrInit();

    //--------------------------------------------------
    // LCD
    //--------------------------------------------------

    lcdInit();

    //--------------------------------------------------
    // Wi-Fi / App Communication
    //
    // The app's Begin command should call pcrStart().
    //--------------------------------------------------

    wifiServerInit();

    //--------------------------------------------------
    // Initialize Scheduler
    //--------------------------------------------------

    unsigned long now = millis();

    lastTemperatureUpdate = now;
    lastPCRUpdate = now;
    lastWiFiUpdate = now;
    lastLCDUpdate = now;

    Serial.println();
    Serial.println("System Ready");
    Serial.println("PCR State: IDLE");
    Serial.println("Waiting for START command from app...");
    Serial.println();
}

//======================================================
// Main Loop
//======================================================

void loop()
{
    unsigned long now = millis();

    //==================================================
    // Temperature Acquisition
    //
    // Sensor updates continuously, even while PCR is idle.
    //==================================================

    if (now - lastTemperatureUpdate >= TEMPERATURE_PERIOD_MS)
    {
        lastTemperatureUpdate = now;

        temperatureUpdate();
    }

    //==================================================
    // Wi-Fi / App Communication
    //
    // Must continue running while PCR is active so the
    // app can request status, pause, resume or stop.
    //==================================================

    if (now - lastWiFiUpdate >= WIFI_UPDATE_PERIOD_MS)
    {
        lastWiFiUpdate = now;

        wifiServerUpdate();
    }

    //==================================================
    // PCR Engine
    //
    // pcrUpdate() itself checks the current state.
    //
    // In PCR_IDLE:
    //   no PID output is applied.
    //
    // In active PCR states:
    //   computePID() -> setTECPower()
    //
    // The main loop does NOT call pcrStart().
    //==================================================

    if (now - lastPCRUpdate >= PCR_UPDATE_PERIOD_MS)
    {
        lastPCRUpdate = now;

        pcrUpdate();
    }

    //==================================================
    // LCD
    //==================================================

    if (now - lastLCDUpdate >= LCD_UPDATE_PERIOD_MS)
    {
        lastLCDUpdate = now;

        lcdUpdate();
    }

    //==================================================
    // Keep ESP32 responsive.
    //==================================================

    delay(1);
}
