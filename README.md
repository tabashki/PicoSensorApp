
Pico Environmental Sensor
=========================

This repo contains the MicroPython firmware and the Swift App code for a simple Bluetooth Low Energy environmental sensor. The hardware is built around a Raspberry Pi Pico W which interfaces with a DHT22 temperature and humidity sensor and a user-togglable two relay module.

The microcontroller communicates its state according to the [Envionmental Sensing Service](https://www.bluetooth.com/specifications/specs/environmental-sensing-service-1-0/) specification, using the standard Characteristics for Temperatue and Humidity. The service exposes a additional private characteristic with the UUID `E04E0525-ECBC-4E2C-AAB6-A3EC009506C6` that is used to read and write the state of the output pins for the relays.

The goal of this project was to get some hands on experience with BLE as well as some Swift programming. It was also used as part of my third-year coursework for my Computer Engineering course at the [Faculty of Physics at Sofia University](https://www.phys.uni-sofia.bg).


Breadboard Wiring Diagram
=========================

There are three hardcoded GPIO pins that are crucial for operation and must be reassigned in [the firmware](SensorFirmware/main.py) if not following the following wiring diagram. All devices and I/Os are ran off the 3.3V regulated rail from the Pi Pico. A 4.7 kΩ pull-up resistor for the Data line on the DHT22 is required.

| Pin Number    | Usage                  |
|---------------|------------------------|
| Pin 34 (GP28) | Onewire Data for DHT22 |
| Pin 32 (GP27) | Relay 1 Output         |
| Pin 31 (GP26) | Relay 2 Output         |

![Wiring Diagram](/doc/wiring.png)


iOS App
=======

The macOS/iOS app presents two views to the user:
- A connecting screen that's displayed while attempting to connect to the sensor over BLE
- A sensor status and control screen when the connection is established

![iOS App Screenshot](/doc/ios_screenshot.png)
