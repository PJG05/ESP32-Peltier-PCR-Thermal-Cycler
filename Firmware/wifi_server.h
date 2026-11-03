#ifndef WIFI_SERVER_H
#define WIFI_SERVER_H

#include <Arduino.h>
#include <IPAddress.h>

//======================================================
// Initialization
//======================================================

void wifiServerInit();

//======================================================
// Update
//======================================================

void wifiServerUpdate();

//======================================================
// Status
//======================================================

bool wifiConnected();

//------------------------------------------------------
// App Connection Status
//
// true  = Flutter/mobile app has successfully contacted
//         the ESP32
//
// false = app has not contacted the ESP32 yet
//         OR Wi-Fi connection was lost
//------------------------------------------------------

bool appConnected();

IPAddress getLocalIP();

#endif