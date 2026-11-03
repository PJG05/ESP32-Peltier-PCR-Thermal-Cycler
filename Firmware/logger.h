#ifndef LOGGER_H
#define LOGGER_H

#include <Arduino.h>

//======================================================
// Log Levels
//======================================================

enum LogLevel
{
    LOG_INFO,
    LOG_WARN,
    LOG_ERROR
};

//======================================================
// Initialization
//======================================================

void loggerInit();

//======================================================
// Logging
//======================================================

void logMessage(LogLevel level, const String &message);

// Convenience wrapper for PCR run milestones (always INFO level)
void logEvent(const String &event);

#endif
