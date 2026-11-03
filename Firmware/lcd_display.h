#ifndef LCD_DISPLAY_H
#define LCD_DISPLAY_H

#include <Arduino.h>

//======================================================
// Initialization
//======================================================

void lcdInit();

//======================================================
// Update
//======================================================

// Redraws the display from current SystemStatus. Call periodically
// (e.g. every LCD_PERIOD_MS) - not every loop() iteration, since
// I2C writes are slow relative to the main loop.
void lcdUpdate();

//======================================================
// Messages
//======================================================

// Briefly overrides the display with a message (e.g. "WiFi Connected",
// "Program Loaded"). Cleared automatically on the next lcdUpdate().
void lcdShowMessage(const String &line1, const String &line2);

#endif
