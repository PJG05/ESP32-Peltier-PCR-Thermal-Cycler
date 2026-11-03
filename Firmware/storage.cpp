#include "storage.h"
#include "protocol.h"
#include "logger.h"

#include <Preferences.h>

//======================================================
// Preferences Namespace
//======================================================

static const char* NVS_NAMESPACE = "pcr_prog";

static Preferences prefs;

//======================================================
// Initialization
//======================================================

void storageInit()
{
    Serial.println("--------------------------------");
    Serial.println("Storage Module Initialized");
    Serial.println("--------------------------------");
}

//======================================================
// Save
//======================================================

void saveProgramToStorage()
{
    PCRProgram &program = getProgram();

    prefs.begin(NVS_NAMESPACE, false);

    prefs.putFloat("initTemp", program.initialTemp);
    prefs.putULong("initHold", program.initialHold);

    prefs.putUChar("stageCnt", program.stageCount);

    for(uint8_t i = 0; i < program.stageCount; i++)
    {
        String tempKey = "sT" + String(i);
        String holdKey = "sH" + String(i);

        prefs.putFloat(tempKey.c_str(), program.stages[i].temperature);
        prefs.putULong(holdKey.c_str(), program.stages[i].holdTime);
    }

    prefs.putUChar("cycles", program.cycles);
    prefs.putFloat("finalTemp", program.finalTemp);
    prefs.putULong("finalHold", program.finalHold);

    prefs.end();

    logMessage(LOG_INFO, "Program saved to flash");
}

//======================================================
// Load
//======================================================

bool loadProgramFromStorage()
{
    prefs.begin(NVS_NAMESPACE, true);

    if(!prefs.isKey("stageCnt"))
    {
        prefs.end();
        return false;
    }

    clearProgram();

    PCRProgram &program = getProgram();

    program.initialTemp = prefs.getFloat("initTemp", 95.0f);
    program.initialHold = prefs.getULong("initHold", 180);

    uint8_t stageCount = prefs.getUChar("stageCnt", 0);

    for(uint8_t i = 0; i < stageCount; i++)
    {
        String tempKey = "sT" + String(i);
        String holdKey = "sH" + String(i);

        float temperature = prefs.getFloat(tempKey.c_str(), 0.0f);
        uint32_t holdTime  = prefs.getULong(holdKey.c_str(), 0);

        addStage(temperature, holdTime);
    }

    program.cycles    = prefs.getUChar("cycles", 35);
    program.finalTemp = prefs.getFloat("finalTemp", 72.0f);
    program.finalHold = prefs.getULong("finalHold", 300);

    prefs.end();

    logMessage(LOG_INFO, "Program restored from flash");

    return true;
}
