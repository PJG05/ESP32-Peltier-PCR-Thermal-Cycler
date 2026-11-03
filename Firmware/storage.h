#ifndef STORAGE_H
#define STORAGE_H

#include <Arduino.h>

//======================================================
// Initialization
//======================================================

void storageInit();

//======================================================
// Program Persistence
//======================================================

// Saves the program currently returned by getProgram() (protocol.h)
// to flash (NVS), so it survives a reboot/power cycle.
void saveProgramToStorage();

// Loads a previously saved program into getProgram(). Returns
// false (and leaves the current program untouched) if nothing was
// ever saved.
bool loadProgramFromStorage();

#endif
