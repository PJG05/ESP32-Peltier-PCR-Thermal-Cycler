#include "lcd_display.h"
#include "config.h"
#include "status.h"
#include "pcr_engine.h"
#include "wifi_server.h"
#include <math.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>   // Library: "LiquidCrystal I2C" by Frank de Brabander

//======================================================
// LCD Instance
//======================================================

static LiquidCrystal_I2C lcd(LCD_ADDRESS, LCD_COLUMNS, LCD_ROWS);

//======================================================
// Helpers
//======================================================

static void printPadded(uint8_t row, const String &text)
{
    String line = text;

    if(line.length() > LCD_COLUMNS)
        line = line.substring(0, LCD_COLUMNS);

    while(line.length() < LCD_COLUMNS)
        line += ' ';

    lcd.setCursor(0, row);
    lcd.print(line);
}

static const char* shortStateLabel(PCRState state, bool ramping)
{
    switch(state)
    {
        case PCR_IDLE:              return "IDLE";
        case PCR_INITIAL_HEATING:   return ramping ? "I-COOL" : "I-HEAT";
        case PCR_INITIAL_HOLD:      return "I-HOLD";
        case PCR_STAGE_HEATING:     return ramping ? "COOL"   : "HEAT";
        case PCR_STAGE_HOLD:        return "HOLD";
        case PCR_NEXT_STAGE:        return "NEXT";
        case PCR_NEXT_CYCLE:        return "NEXT";
        case PCR_FINAL_HEATING:     return ramping ? "F-COOL" : "F-HEAT";
        case PCR_FINAL_HOLD:        return "F-HOLD";
        case PCR_FINISHED:          return "DONE";
        case PCR_PAUSED:            return "PAUSE";
        case PCR_ERROR:             return "ERROR";
        default:                    return "?";
    }
}

//======================================================
// Initialization
//======================================================

void lcdInit()
{
    // Uses the ESP32's default I2C pins (GPIO21=SDA, GPIO22=SCL).
    // If your LCD is wired to different pins, call
    // Wire.begin(sdaPin, sclPin) instead and add those pin
    // numbers to config.h.
    Wire.begin();

    lcd.init();
    lcd.backlight();

    printPadded(0, FIRMWARE_NAME);
    printPadded(1, "Booting...");

    Serial.println("--------------------------------");
    Serial.println("LCD Display Initialized");
    Serial.println("--------------------------------");
}

//======================================================
// Update
//======================================================

void lcdUpdate()
{
    SystemStatus &status = getStatus();
    PCRState state = getPCRState();

    //==================================================
    // APP NOT CONNECTED
    //
    // Wi-Fi may already be connected.
    //
    // Display:
    //
    // Pls Conn to IP
    // 172.16.233.120
    //
    // This remains until the Flutter app actually
    // communicates with the ESP32.
    //==================================================

    if(!appConnected())
    {
        printPadded(0, "Pls Conn to IP");
        printPadded(1, getLocalIP().toString());

        return;
    }

    //==================================================
    // APP CONNECTED
    //
    // Existing display behaviour remains unchanged.
    //==================================================

    //--------------------------------------------------
    // Row 0: Temperature
    //--------------------------------------------------

    //--------------------------------------------------
    // Beautified Display Temperature (Presentation Only)
    //--------------------------------------------------

    float displayTemperature = status.currentTemperature;

    if (status.phase == "Holding")
    {
        if (fabs(status.currentTemperature -
                 status.targetTemperature) <= 1.0f)
        {
            displayTemperature = status.targetTemperature;
        }
    }

    String row0 = "T:" + String(displayTemperature, 1) +
                  ">" + String(status.targetTemperature, 1);

    if(status.heater)
        row0 += " H";
    else if(status.cooler)
        row0 += " C";

    if(!status.sensorConnected)
        row0 = "SENSOR FAULT!";

    printPadded(0, row0);

    //--------------------------------------------------
    // Row 1: State / Cycle, or IP address while idle
    //--------------------------------------------------

    String row1;

    if(state == PCR_IDLE)
    {
        if(wifiConnected())
            row1 = getLocalIP().toString();
        else
            row1 = "WiFi: offline";
    }
    else
    {
        //--------------------------------------------------
        // HOLD TIMER
        //
        // The LCD reads ONLY the ESP32 PCR engine state
        // and status.holdRemaining. It does not depend
        // on Wi-Fi, Flutter, or status.phase strings.
        //--------------------------------------------------

        bool isHoldState =
            (state == PCR_INITIAL_HOLD ||
             state == PCR_STAGE_HOLD ||
             state == PCR_FINAL_HOLD);

        if(isHoldState)
        {
            unsigned long totalSeconds =
                (status.holdRemaining + 999UL) / 1000UL;

            unsigned long minutes =
                totalSeconds / 60UL;

            unsigned long seconds =
                totalSeconds % 60UL;

            row1 =
                "HOLD " +
                String(minutes) +
                ":" +
                (seconds < 10 ? "0" : "") +
                String(seconds);
        }
        else
        {
            bool ramping =
                (status.targetTemperature <
                 status.currentTemperature);

            row1 =
                String(shortStateLabel(state, ramping)) +
                " C" +
                String(status.cycle) +
                "/" +
                String(status.totalCycles);
        }
    }

    printPadded(1, row1);
}

//======================================================
// Messages
//======================================================

void lcdShowMessage(const String &line1, const String &line2)
{
    printPadded(0, line1);
    printPadded(1, line2);
}