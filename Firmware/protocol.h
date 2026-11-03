#ifndef PROTOCOL_H
#define PROTOCOL_H

#include <Arduino.h>

#define MAX_STAGES 10

//======================================================
// PCR Stage
//======================================================

struct PCRStage
{
    float temperature;
    uint32_t holdTime;      // seconds
};

//======================================================
// PCR Program
//======================================================

struct PCRProgram
{
    float initialTemp;
    uint32_t initialHold;

    PCRStage stages[MAX_STAGES];

    uint8_t stageCount;
    uint8_t cycles;

    float finalTemp;
    uint32_t finalHold;
};

//======================================================
// Functions
//======================================================

void protocolInit();

PCRProgram& getProgram();

void loadDefaultProgram();

void clearProgram();

bool addStage(float temperature, uint32_t holdTime);

uint32_t getCurrentStageHoldTime(uint8_t stage);

#endif