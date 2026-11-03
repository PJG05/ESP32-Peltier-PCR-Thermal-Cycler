# Flutter Application Source (`lib/`)

This directory contains the primary source code of the Flutter-based Android application developed for the ESP32 Peltier PCR Thermal Cycler.

## Overview

The application provides a mobile interface for configuring PCR programs, communicating with the ESP32 controller, monitoring thermal cycling, and generating experimental reports.

## Main Functionalities

- PCR program creation and configuration
- Temperature, hold time, and cycle count configuration
- Live PCR monitoring
- Start, pause, resume, and stop controls
- ESP32 Wi-Fi communication
- Real-time temperature telemetry
- Temperature profile visualization
- PCR report generation
- Saved PCR programs
- Device settings and connection management

## Architecture

The Flutter application communicates with the ESP32 through HTTP-based communication over Wi-Fi.

The ESP32 independently executes the PCR thermal cycling process, while the application provides configuration, monitoring, and user interaction.

## Technologies

- Flutter
- Dart
- HTTP communication
- Wi-Fi connectivity
- Telemetry visualization
- Local data storage
