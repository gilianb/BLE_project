import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // List to store discovered Bluetooth Low Energy (BLE) devices
  List<BluetoothDevice> devicesList = [];

  // The currently connected BLE device
  BluetoothDevice? connectedDevice;

  // The writable characteristic of the connected device
  BluetoothCharacteristic? writeCharacteristic;

  // Function to scan for nearby BLE devices
  void scanForDevices() {
    // Clear the list before scanning to avoid duplicates
    devicesList.clear();

    // Start scanning for BLE devices with a timeout of 5 seconds
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    // Listen to scan results and update the list of discovered devices
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        // Add device to list if not already present
        if (!devicesList.contains(result.device)) {
          setState(() {
            devicesList.add(result.device);
          });
        }
      }
    });
  }

  // Function to connect to a selected BLE device
  Future<void> connectToDevice(BluetoothDevice device) async {
    // Attempt to connect to the device
    await device.connect();

    // Update the UI to reflect the connected device
    setState(() {
      connectedDevice = device;
    });

    // Discover available services and characteristics of the connected device
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        // Check if the characteristic supports writing
        if (characteristic.properties.write) {
          writeCharacteristic = characteristic;
          break; // Stop searching once we find a writable characteristic
        }
      }
    }
  }

  // Function to send data to the connected ESP32 device
  void sendData() async {
    if (writeCharacteristic != null) {
      List<int> data = utf8.encode("hello");
      await writeCharacteristic!
          .write(data); // Example: Sending hello to the app
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // Button to start scanning for BLE devices
          ElevatedButton(
            onPressed: scanForDevices,
            child: const Text("Scan BLE devices"),
          ),
          // List of discovered BLE devices
          Expanded(
            child: ListView.builder(
              itemCount: devicesList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  // Display the name of the device if available, otherwise show "Unknown device"
                  title: Text(devicesList[index].name.isNotEmpty
                      ? devicesList[index].name
                      : "Unknown device"),
                  // Display the unique ID (MAC address) of the device
                  subtitle: Text(devicesList[index].id.toString()),
                  // Tap to connect to the selected device
                  onTap: () => connectToDevice(devicesList[index]),
                );
              },
            ),
          ),
          // Button to send data to the connected ESP32 (only visible if a device is connected)
          if (connectedDevice != null)
            ElevatedButton(
              onPressed: sendData,
              child: const Text("Send data to ESP32"),
            ),
        ],
      ),
    );
  }
}
