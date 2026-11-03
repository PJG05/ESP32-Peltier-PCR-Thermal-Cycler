# PCR Thermal Cycler Hardware

This directory documents the hardware architecture and physical implementation of the indigenous Peltier-based PCR thermal cycler.

## Hardware Components

| Component | Purpose |
|---|---|
| ESP32 | Embedded control and Wi-Fi communication |
| PT1000 RTD | Temperature measurement |
| MAX31865 | RTD interface and signal conversion |
| Peltier Module | Heating and cooling |
| IBT-4 H-Bridge | Bidirectional Peltier drive |
| Aluminium Block | Sample thermal chamber |
| Heat Sink | Hot-side heat dissipation |
| Cooling Fans | Forced-air heat rejection |
| LCD | Local system status display |

## Hardware Architecture

The ESP32 reads the PT1000 temperature sensor through the MAX31865 interface and regulates the Peltier module using the temperature control algorithm.

The aluminium block provides the thermal interface for PCR samples, while the heat sink and fans dissipate heat from the Peltier hot side.

## Documentation

This directory can contain:
- Hardware photographs
- Wiring diagrams
- Circuit diagrams
- Assembly documentation
- Thermal block design
- Component specifications
