# Bluetooth Low Energy (BLE) Project

This repository contains a Bluetooth Low Energy (BLE) project demonstrating how to use BLE in a Flutter/Dart Android app to communicate with an ESP32 device.

## Features
- **Example 1: Basic Read/Write** - Connects to ESP32, sends and receives data.
- **Example 2: Multiple Characteristics** - Reads and writes multiple BLE characteristics simultaneously, including real-time notifications (e.g., temperature sensor).
- **Example 3: Large Data Transfer** - Splits large packets (300 bytes) into smaller BLE-compatible chunks (17 bytes per packet) and reconstructs them on the app side.

## Setup
1. Install dependencies (`flutter_blue_plus: ^1.34.5` in `pubspec.yaml`).
2. Add necessary BLE permissions in `AndroidManifest.xml`.
3. Load the corresponding ESP32 BLE firmware.

## Demo Videos
Short demonstration videos for each example are available in the `Video/Final_video` folder.

---
Developed by Gilian Bensoussan

