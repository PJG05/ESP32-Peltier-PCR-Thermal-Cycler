#ifndef CONFIG_H
#define CONFIG_H

//======================================================
// WiFi Credentials
//======================================================

extern const char* WIFI_SSID;
extern const char* WIFI_PASSWORD;

//======================================================
// Firmware Information
//======================================================

#define FIRMWARE_NAME      "PCR Firmware V2"
#define FIRMWARE_VERSION   "2.0.0"

//======================================================
// LCD Configuration
//======================================================

#define LCD_ADDRESS        0x27
#define LCD_COLUMNS        16
#define LCD_ROWS           2

//======================================================
// MAX31865 Configuration
//======================================================

#define MAX31865_CS        5

#define MAX31865_MOSI      23
#define MAX31865_MISO      19
#define MAX31865_SCK       18

//======================================================
// PT1000 Configuration
//======================================================

#define RNOMINAL           1000.0f
#define RREF               4301.0f

//======================================================
// TEC Driver (IBT-4)
//======================================================

#define TEC_IN1_PIN        25
#define TEC_IN2_PIN        26

#define PWM_FREQ           20000
#define PWM_RESOLUTION     8

//======================================================
// Fan
//======================================================

#define FAN_PIN            27

//======================================================
// Temperature Safety Limits
//======================================================

#define MAX_SAFE_TEMP      110.0f
#define MIN_SAFE_TEMP      -20.0f

//======================================================
// PID Hold Parameters
//
// These gains are used primarily after target acquisition.
// Ramp/landing behaviour is handled by the gain-scheduled
// thermal controller in pid_controller.cpp.
//======================================================

#define DEFAULT_KP         15.0f
#define DEFAULT_KI         0.35f
#define DEFAULT_KD         25.0f

//======================================================
// Stability Detection
//
// A PCR hold begins only after the measured temperature
// remains inside TEMP_TOLERANCE for STABLE_TIME_MS.
//
// The PCR engine also counts valid hold time only while
// temperature remains inside the tolerance window.
//======================================================

#define TEMP_TOLERANCE     0.30f
#define STABLE_TIME_MS     3000UL

//======================================================
// Safety Timeouts
//======================================================

// Maximum time allowed for a heating stage before
// declaring something is wrong (TEC, sensor, PID, etc.)
#define HEATING_TIMEOUT_MS    600000UL    // 10 minutes

// Maximum time allowed for any individual PCR stage
#define STAGE_TIMEOUT_MS      900000UL    // 15 minutes

//======================================================
// Scheduler
//======================================================

#define PCR_UPDATE_PERIOD_MS     200UL
#define WIFI_UPDATE_PERIOD_MS    250UL
#define LCD_UPDATE_PERIOD_MS     500UL

//======================================================
// Loop Timing
//======================================================

#define TEMPERATURE_PERIOD_MS    200UL
#define PID_PERIOD_MS            200UL
#define STATUS_PERIOD_MS         500UL
#define LCD_PERIOD_MS            500UL

//======================================================
// Final Storage Hold
//
// After PCR cycling and final extension complete,
// the engine actively maintains this temperature until
// the user stops the run.
//======================================================

#define DEFAULT_HOLD_TEMP        4.0f



#endif
