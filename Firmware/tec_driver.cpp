#include "tec_driver.h"
#include "config.h"
#include "status.h"

#include <Arduino.h>

//======================================================
// Internal Variables
//======================================================

static bool heaterState = false;
static bool coolerState = false;

static uint8_t currentPWM = 0;

//======================================================
// Initialization
//======================================================

void tecInit()
{
    ledcAttach(
        TEC_IN1_PIN,
        PWM_FREQ,
        PWM_RESOLUTION
    );

    ledcAttach(
        TEC_IN2_PIN,
        PWM_FREQ,
        PWM_RESOLUTION
    );

    stopTEC();

    Serial.println("--------------------------------");
    Serial.println("TEC Driver Initialized");
    Serial.println("--------------------------------");
}

//======================================================
// Heating
//======================================================

void heaterPWM(uint8_t pwm)
{
    pwm = constrain(pwm, 0, 255);

    ledcWrite(TEC_IN1_PIN, pwm);
    ledcWrite(TEC_IN2_PIN, 0);

    heaterState = (pwm > 0);
    coolerState = false;

    currentPWM = pwm;

    auto &status = getStatus();

    status.heater = heaterState;
    status.cooler = coolerState;
    status.pwm = currentPWM;
}

//======================================================
// Cooling
//======================================================

void coolerPWM(uint8_t pwm)
{
    pwm = constrain(pwm, 0, 255);

    ledcWrite(TEC_IN1_PIN, 0);
    ledcWrite(TEC_IN2_PIN, pwm);

    coolerState = (pwm > 0);
    heaterState = false;

    currentPWM = pwm;
    auto &status = getStatus();

    status.heater = heaterState;
    status.cooler = coolerState;
    status.pwm = currentPWM;
}

//======================================================
// Stop
//======================================================

void stopTEC()
{
    ledcWrite(TEC_IN1_PIN, 0);
    ledcWrite(TEC_IN2_PIN, 0);

    heaterState = false;
    coolerState = false;

    currentPWM = 0;
    auto &status = getStatus();

    status.heater = false;
    status.cooler = false;
    status.pwm = 0;
}

//======================================================
// Automatic Direction
//======================================================

void setTECPower(int pwm)
{
    pwm = constrain(pwm, -255, 255);

    if (pwm > 0)
    {
        heaterPWM((uint8_t)pwm);
    }
    else if (pwm < 0)
    {
        coolerPWM((uint8_t)(-pwm));
    }
    else
    {
        stopTEC();
    }
}

//======================================================
// Status
//======================================================

bool heaterRunning()
{
    return heaterState;
}

bool coolerRunning()
{
    return coolerState;
}

uint8_t getPWMOutput()
{
    return currentPWM;
}