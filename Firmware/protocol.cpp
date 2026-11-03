#include "protocol.h"

//======================================================
// Internal Storage
//======================================================

static PCRProgram currentProgram;

//======================================================
// Initialize
//======================================================

void protocolInit()
{
    loadDefaultProgram();

    Serial.println("--------------------------------");
    Serial.println("Protocol Module Initialized");
    Serial.println("--------------------------------");
}

//======================================================
// Get Current Program
//======================================================

PCRProgram& getProgram()
{
    return currentProgram;
}

//======================================================
// Clear Program
//======================================================

void clearProgram()
{
    currentProgram.initialTemp = 25.0f;
    currentProgram.initialHold = 0;

    currentProgram.stageCount = 0;
    currentProgram.cycles = 0;

    currentProgram.finalTemp = 4.0f;
    currentProgram.finalHold = 0;
}

//======================================================
// Add Stage
//======================================================

bool addStage(float temperature, uint32_t holdTime)
{
    if(currentProgram.stageCount >= MAX_STAGES)
        return false;

    currentProgram.stages[currentProgram.stageCount].temperature = temperature;
    currentProgram.stages[currentProgram.stageCount].holdTime = holdTime;

    currentProgram.stageCount++;

    return true;
}

//======================================================
// Default Program
//======================================================

void loadDefaultProgram()
{
    clearProgram();

    currentProgram.initialTemp = 95.0f;
    currentProgram.initialHold = 180;

    currentProgram.cycles = 35;

    addStage(95.0f,30);

    addStage(60.0f,30);

    addStage(72.0f,45);

    currentProgram.finalTemp = 72.0f;
    currentProgram.finalHold = 300;
}

uint32_t getCurrentStageHoldTime(uint8_t stage)
{
    if(stage >= currentProgram.stageCount)
        return 0;

    return currentProgram.stages[stage].holdTime;
}