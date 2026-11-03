#include "wifi_server.h"

#include "config.h"

#include "status.h"

#include "protocol.h"

#include "pcr_engine.h"

#include "logger.h"

#include "storage.h"

#include "pid_controller.h"

#include <WiFi.h>

#include <WebServer.h>

#include <ESPmDNS.h>       // Bundled with ESP32 Arduino core

#include <ArduinoJson.h>   // Library: "ArduinoJson" by Benoit Blanchon (v6.x)

//======================================================

// Server Instance

//======================================================

static WebServer server(80);

static bool connected = false;

static bool appConnectedFlag = false;

//======================================================

// Helpers

//======================================================

static void sendCORS()

{

    server.sendHeader("Access-Control-Allow-Origin", "*");

    server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");

    server.sendHeader("Access-Control-Allow-Headers", "Content-Type");

    // Chrome's Private Network Access policy blocks a webpage from

    // fetching a private-IP device (like this ESP32) unless the

    // server explicitly allows it here - without this header, Chrome

    // silently blocks the request even after a "successful" preflight.

    server.sendHeader("Access-Control-Allow-Private-Network", "true");

}

static void sendOK(const char* body = "OK")

{

    sendCORS();

    server.send(200, "text/plain", body);

}

static void sendError(int code, const char* message)

{

    sendCORS();

    server.send(code, "text/plain", message);

}

//======================================================

// Route Handlers

//======================================================

static void handlePing()
{
    appConnectedFlag = true;
    sendOK("pong");
}

static void handleOptions()

{

    sendCORS();

    server.send(204);

}

//------------------------------------------------------

// GET /status

//------------------------------------------------------

    static void handleStatus()
{
    appConnectedFlag = true;

    SystemStatus &status = getStatus();

    StaticJsonDocument<768> doc;

    //--------------------------------------------------

    // Fields required by the Flutter app's LiveStatus model

    //--------------------------------------------------

    doc["temperature"] = status.currentTemperature;

    doc["target"]       = status.targetTemperature;

    doc["heater"]       = status.heater;

    doc["cooling"]      = status.cooler;

    doc["running"]      = status.running;

    doc["stage"]        = status.state;          // internal state

    doc["stageName"]    = status.stageName;  // Denaturation / Annealing / ...

    doc["phase"]        = status.phase;          // Heating / Cooling / Holding

    doc["cycle"]        = status.cycle;

    doc["resistance"]   = status.resistance;

    //--------------------------------------------------

    // Extra diagnostic fields (safe to ignore on the app side

    //--------------------------------------------------

    doc["paused"]           = status.paused;

    doc["finished"]         = status.finished;

    doc["stageIndex"]       = status.stage;

    doc["totalStages"]      = status.totalStages;

    doc["totalCycles"]      = status.totalCycles;

    // ESP32 remains the timing authority.

    // Keep the old field for compatibility with existing app code.

    doc["holdRemaining"] = status.holdRemaining / 1000UL;

    // New precise timer value for the Flutter display.

    doc["holdRemainingMs"] = status.holdRemaining;

    // NOTE: status.holdRemaining is tracked internally in ms

    // (pcr_engine.cpp) for precision, but the app does

    // Duration(seconds: holdRemaining) - sending raw ms here was

    // showing garbage minute:second values (e.g. 180000 read as

    // 180000 seconds instead of 180).

    doc["pwm"]               = status.pwm;

    doc["sensorConnected"]  = status.sensorConnected;

    doc["sensorFault"]      = status.sensorFault;

    doc["emergencyStop"]    = status.emergencyStop;

    doc["firmware"]         = FIRMWARE_VERSION;

    float kp, ki, kd;

    getPIDTunings(kp, ki, kd);

    doc["kp"] = kp;

    doc["ki"] = ki;

    doc["kd"] = kd;

    doc["zone"] = getFarZoneThreshold();

    String output;

    serializeJson(doc, output);

    sendCORS();

    server.sendHeader("Cache-Control", "no-store");

    server.send(200, "application/json", output);

}

//------------------------------------------------------

// GET /start /pause /resume /stop

//------------------------------------------------------

static void handleStart()

{

    // PCR can begin only through an explicit request to /start.

    // Repeated START requests while already running must not restart

    // the state machine or re-arm the thermal ramp controller.

    if(pcrRunning())

    {

        sendOK("Already running");

        return;

    }

    Serial.println("Explicit START command received from app");

    pcrStart();

    if(pcrRunning())

    {

        sendOK("Started");

    }

    else

    {

        // pcrStart() no-ops if there is no valid program or the

        // temperature sensor is unavailable.

        sendError(400, "Cannot start: no program loaded or sensor not connected");

    }

}

static void handlePause()

{

    pcrPause();

    sendOK();

}

static void handleResume()

{

    pcrResume();

    sendOK();

}

static void handleStop()

{

    pcrStop();

    sendOK();

}

//------------------------------------------------------

// GET /program

//

// Returns the PCR program currently loaded in ESP32 RAM.

//

// IMPORTANT:

// This is only for reconstructing the Flutter UI.

// It does NOT control PCR execution or timing.

//------------------------------------------------------

static void handleGetProgram()

{

    PCRProgram &program = getProgram();

    StaticJsonDocument<2048> doc;

    doc["name"] = "ESP32 PCR Program";

    doc["initialTemp"] = program.initialTemp;

    doc["initialHold"] = program.initialHold;

    JsonArray stages = doc.createNestedArray("stages");

    for(uint8_t i = 0; i < program.stageCount; i++)

    {

        JsonObject stage = stages.createNestedObject();

        stage["stageName"] =

            String("Stage ") + String(i + 1);

        stage["temperature"] =

            program.stages[i].temperature;

        stage["holdTime"] =

            program.stages[i].holdTime;

        // Flutter needs a color value.

        // This is only UI information.

        stage["stageColor"] = 0xFF2196F3;

    }

    doc["cycles"] = program.cycles;

    doc["finalTemp"] = program.finalTemp;

    doc["finalHold"] = program.finalHold;

    String output;

    serializeJson(doc, output);

    sendCORS();

    server.sendHeader(

        "Cache-Control",

        "no-store"

    );

    server.send(

        200,

        "application/json",

        output

    );

}

//------------------------------------------------------

// POST /program

//------------------------------------------------------

static void handleProgram()

{

    if(!server.hasArg("plain"))

    {

        sendError(400, "Missing JSON body");

        return;

    }

    StaticJsonDocument<2048> doc;

    DeserializationError err = deserializeJson(doc, server.arg("plain"));

    if(err)

    {

        logMessage(LOG_ERROR, String("Program JSON parse failed: ") + err.c_str());

        sendError(400, "Invalid JSON");

        return;

    }

    // Refuse to overwrite an active program mid-run

    if(pcrRunning() && !pcrPaused())

    {

        sendError(409, "Cannot upload a program while PCR is running");

        return;

    }

    clearProgram();

    PCRProgram &program = getProgram();

    program.initialTemp = doc["initialTemp"] | 95.0f;

    program.initialHold = doc["initialHold"] | 180;

    JsonArray stages = doc["stages"].as<JsonArray>();

    for(JsonObject stage : stages)

    {

        float temperature = stage["temperature"] | 0.0f;

        uint32_t holdTime  = stage["holdTime"] | 0;

        if(!addStage(temperature, holdTime))

        {

            logMessage(LOG_WARN, "Program upload: MAX_STAGES exceeded, extra stages dropped");

            break;

        }

    }

    program.cycles    = doc["cycles"] | 35;

    program.finalTemp = doc["finalTemp"] | 72.0f;

    program.finalHold = doc["finalHold"] | 300;

    logMessage(LOG_INFO, String("Program uploaded: ") + program.stageCount +

                              " stages, " + program.cycles + " cycles");

    saveProgramToStorage();

    sendOK();

}

//------------------------------------------------------

// GET /pid - read or live-tune Kp/Ki/Kd/zone without reflashing

//------------------------------------------------------

// Examples:

//   GET /pid                          -> report current tunings

//   GET /pid?kp=15&ki=0.2&kd=5        -> set new gains

//   GET /pid?zone=2                   -> set far-zone bang-bang

//                                         cutover distance (degrees)

// Any of kp/ki/kd/zone may be omitted to leave that value unchanged.

static void handlePID()

{

    float kp, ki, kd;

    getPIDTunings(kp, ki, kd);

    float zone = getFarZoneThreshold();

    bool changed = false;

    if(server.hasArg("kp")) { kp = server.arg("kp").toFloat(); changed = true; }

    if(server.hasArg("ki")) { ki = server.arg("ki").toFloat(); changed = true; }

    if(server.hasArg("kd")) { kd = server.arg("kd").toFloat(); changed = true; }

    if(server.hasArg("zone"))

    {

        zone = server.arg("zone").toFloat();

        setFarZoneThreshold(zone);

        changed = true;

    }

    if(changed)

    {

        setPIDTunings(kp, ki, kd);

        // Reset the integral/derivative history so the new gains

        // don't act on accumulated error from the old tuning.

        resetPID();

        logMessage(LOG_INFO, "PID tunings updated: kp=" + String(kp) +

                                  " ki=" + String(ki) + " kd=" + String(kd) +

                                  " zone=" + String(zone));

    }

    StaticJsonDocument<128> doc;

    doc["kp"] = kp;

    doc["ki"] = ki;

    doc["kd"] = kd;

    doc["zone"] = zone;

    String output;

    serializeJson(doc, output);

    sendCORS();

    server.send(200, "application/json", output);

}

//------------------------------------------------------

// 404

//------------------------------------------------------

static void handleNotFound()

{

    // Browsers preflight with OPTIONS before many cross-origin

    // requests. Rather than registering an OPTIONS route for every

    // single endpoint individually, treat any OPTIONS request that

    // didn't match a specific handler as an allowed preflight - only

    // GET/POST requests that don't match anything are real 404s.

    if(server.method() == HTTP_OPTIONS)

    {

        sendCORS();

        server.send(204);

        return;

    }

    sendError(404, "Not found");

}

//======================================================

// Initialization

//======================================================

void wifiServerInit()

{

    Serial.println("--------------------------------");

    Serial.print("Connecting to WiFi: ");

    Serial.println(WIFI_SSID);

    WiFi.mode(WIFI_STA);

    // Modem sleep saves power by periodically dropping the radio

    // between beacon intervals - this is a known cause of

    // intermittent-feeling drops/latency with some routers.

    // Disabling it costs a bit of power draw but trades that for

    // more reliable, consistent connectivity - worth it for a

    // device that's meant to stay controllable throughout a run.

    WiFi.setSleep(false);

    WiFi.setAutoReconnect(true);

    WiFi.persistent(false); // Avoid unnecessary flash writes during recovery.

    // Logs WHY a disconnect happened (auth failure, beacon timeout,

    // AP not found, etc.) instead of just "it dropped" - if it

    // happens again, this tells us the actual reason instead of

    // guessing between router issue / interference / power issue.

    WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info)

    {

        if(event == ARDUINO_EVENT_WIFI_STA_DISCONNECTED)

        {

            logMessage(LOG_WARN,

                String("WiFi disconnected, reason code: ") +

                String(info.wifi_sta_disconnected.reason));

        }

    });

#if USE_STATIC_IP

    IPAddress staticIP(STATIC_IP_1, STATIC_IP_2, STATIC_IP_3, STATIC_IP_4);

    IPAddress gateway(STATIC_GATEWAY_1, STATIC_GATEWAY_2, STATIC_GATEWAY_3, STATIC_GATEWAY_4);

    IPAddress subnet(STATIC_SUBNET_1, STATIC_SUBNET_2, STATIC_SUBNET_3, STATIC_SUBNET_4);

    if(!WiFi.config(staticIP, gateway, subnet))

    {

        Serial.println("Static IP config failed - falling back to DHCP");

    }

#endif

    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    unsigned long startAttempt = millis();

    const unsigned long WIFI_CONNECT_TIMEOUT_MS = 15000;

    while(WiFi.status() != WL_CONNECTED &&

          millis() - startAttempt < WIFI_CONNECT_TIMEOUT_MS)

    {

        delay(250);

        Serial.print(".");

    }

    Serial.println();

    if(WiFi.status() == WL_CONNECTED)

    {

        connected = true;

        Serial.print("WiFi connected. IP address: ");

        Serial.println(WiFi.localIP());

        //--------------------------------------------------

        // mDNS - reachable at http\://pcr.local regardless of

        // whatever IP DHCP hands out this time. DHCP leases can

        // (and will) change across reboots unless you've reserved

        // one on your router, which was silently breaking the

        // app's hardcoded IP every time it changed.

        //--------------------------------------------------

        if(MDNS.begin("pcr"))

        {

            MDNS.addService("http", "tcp", 80);

            Serial.println("mDNS responder started: http\://pcr.local");

        }

        else

        {

            Serial.println("mDNS setup failed - falling back to IP only");

        }

    }

    else

    {

        connected = false;

        Serial.println("WiFi connection FAILED - continuing offline.");

        Serial.println("PCR will still run locally; app control unavailable.");

    }

    server.on("/ping",    HTTP_GET,     handlePing);

    server.on("/status",  HTTP_GET,     handleStatus);

    server.on("/start",   HTTP_GET,     handleStart);

    server.on("/pause",   HTTP_GET,     handlePause);

    server.on("/resume",  HTTP_GET,     handleResume);

    server.on("/stop",    HTTP_GET,     handleStop);

    server.on("/program", HTTP_GET, handleGetProgram);

    server.on("/program", HTTP_POST,    handleProgram);

    server.on("/program", HTTP_OPTIONS, handleOptions);

    server.on("/pid",     HTTP_GET,     handlePID);

    server.onNotFound(handleNotFound);

    server.begin();

    Serial.println("--------------------------------");

    Serial.println("WiFi Server Initialized");

    Serial.println("--------------------------------");

}

//======================================================

// Update

//======================================================

void wifiServerUpdate()

{

    // Keep recovery asynchronous: no long wait loops here, so the PCR

    // scheduler continues to run while Wi-Fi is unavailable.

    static unsigned long lastStateCheck = 0;

    static unsigned long lastReconnectAction = 0;

    static uint8_t reconnectAttempts = 0;

    static bool wasConnected = false;

    static bool firstStateCheck = true;

    const unsigned long STATE_CHECK_MS = 1000UL;

    const unsigned long RECONNECT_ACTION_MS = 3000UL;

    const uint8_t RECONNECT_BEFORE_RESTART = 3;

    const unsigned long now = millis();

    if (now - lastStateCheck >= STATE_CHECK_MS)

    {

        lastStateCheck = now;

        const bool linkUp = (WiFi.status() == WL_CONNECTED);

        // Establish the initial baseline without treating normal startup

        // as a recovery event.

        if (firstStateCheck)

        {

            firstStateCheck = false;

            wasConnected = linkUp;

            connected = linkUp;

        }

        if (linkUp)

        {

            connected = true;

            // Detect the transition back online, then refresh the server

            // listener and mDNS announcement in case the network stack

            // lost either during the outage. Routes are registered once

            // in wifiServerInit(); do not register them again here.

            if (!wasConnected)

            {

                logMessage(LOG_INFO, String("WiFi restored. IP: ") + WiFi.localIP().toString());

                server.begin();

                MDNS.end();

                if (MDNS.begin("pcr"))

                    MDNS.addService("http", "tcp", 80);

                reconnectAttempts = 0;

            }

            wasConnected = true;

        }

        else

        {

            if (wasConnected)

                logMessage(LOG_WARN, "WiFi link lost; PCR control continues locally");

            connected = false;
            appConnectedFlag = false;
            wasConnected = false;

            // Throttle recovery actions. First try the SDK reconnect; if

            // repeated reconnects fail, restart station association using

            // the saved SSID/password. All calls are non-waiting requests.

            if (now - lastReconnectAction >= RECONNECT_ACTION_MS)

            {

                lastReconnectAction = now;

                ++reconnectAttempts;

                if (reconnectAttempts < RECONNECT_BEFORE_RESTART)
                {
                    // Ask the Wi-Fi driver to reconnect without blocking the PCR loop.
                    // If it cannot start a reconnect, immediately try a fresh association.
                    if (WiFi.reconnect())
                    {
                        logMessage(LOG_WARN, "WiFi reconnect requested");
                    }
                    else
                    {
                        logMessage(LOG_WARN, "WiFi reconnect request failed; restarting station association");
                        WiFi.disconnect(false, false);
                        WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
                        reconnectAttempts = 0;
                    }
                }

                else

                {

                    reconnectAttempts = 0;

                    logMessage(LOG_WARN, "WiFi reconnect stalled; restarting station association");

                    WiFi.disconnect(false, false);

                    delay(1); // Yield briefly to the Wi-Fi task; not a reconnect wait.

                    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

                }

            }

        }

    }

    // Service HTTP only while the station link is actually up. Never let

    // a stale cached \`connected\` flag drive request processing.

    if (WiFi.status() == WL_CONNECTED)

        server.handleClient();

}

//======================================================

// Status

//======================================================

bool wifiConnected()
{
    return connected;
}

bool appConnected()
{
    return appConnectedFlag;
}

IPAddress getLocalIP()
{
    return WiFi.localIP();
}
