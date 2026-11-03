#include "logger.h"

//======================================================
// Initialization
//======================================================

void loggerInit()
{
    Serial.println("--------------------------------");
    Serial.println("Logger Initialized");
    Serial.println("--------------------------------");
}

//======================================================
// Internal Helper
//======================================================

static const char* levelTag(LogLevel level)
{
    switch(level)
    {
        case LOG_INFO:  return "INFO ";
        case LOG_WARN:  return "WARN ";
        case LOG_ERROR: return "ERROR";
        default:        return "?????";
    }
}

//======================================================
// Logging
//======================================================

void logMessage(LogLevel level, const String &message)
{
    unsigned long now = millis();

    Serial.print("[");
    Serial.print(now);
    Serial.print(" ms] [");
    Serial.print(levelTag(level));
    Serial.print("] ");
    Serial.println(message);
}

void logEvent(const String &event)
{
    logMessage(LOG_INFO, event);
}
