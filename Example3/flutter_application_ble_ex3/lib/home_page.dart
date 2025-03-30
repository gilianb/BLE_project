import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'scan_screen.dart';
import 'widgets/bluetooth_device_provider';
import 'widgets/snackbar.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.id});
  final String title;
  final String? id;

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  Map<int, String> receivedPackets = {};
  int totalPackets = -1;
  bool isReading = false;
  String completeData = "";

  Future<void> sendRequestAndReadResponse(BluetoothDevice device) async {
    setState(() {
      isReading = true;
      receivedPackets.clear();
      totalPackets = -1;
    });

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.characteristicUuid ==
            Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8")) {
          // Step 1: Send "0" to request data transmission
          if (characteristic.properties.write) {
            await characteristic
                .write([48], withoutResponse: false); // "0" in ASCII
            print("Command '0' sent to the ESP32");
          }

          // Step 2: Enable notifications to receive data
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);

            characteristic.onValueReceived.listen((List<int> data) async {
              if (data.length == 2 && totalPackets == -1) {
                // Step 3: Receive the total number of packets
                totalPackets = data[0] | (data[1] << 8);
                print("Total number of packets received: $totalPackets");

                // Step 4: Send "ACK" to the ESP32
                await characteristic.write(utf8.encode("ACK"),
                    withoutResponse: false);
                print("ACK sent to the ESP32");
              } else if (data.length >= 3) {
                // Step 5: Collect the packets and reconstruct the large data
                int packetIndex = data[0] | (data[1] << 8);
                String receivedChunk = String.fromCharCodes(data.sublist(2));

                receivedPackets[packetIndex] = receivedChunk;
                print("Received packet $packetIndex: $receivedChunk");

                // Step 6: Check if all packets have been received
                if (totalPackets != -1 &&
                    receivedPackets.length == totalPackets) {
                  List<MapEntry<int, String>> sortedEntries =
                      receivedPackets.entries.toList();
                  sortedEntries.sort((a, b) => a.key.compareTo(b.key));

                  completeData =
                      sortedEntries.map((entry) => entry.value).join('');

                  print("Complete data reconstructed: $completeData");
                  setState(() {
                    isReading = false;
                  });

                  // Display a message with the complete data
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Complete data received"),
                        content: Text(completeData),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                }
              }
            });
          }

          return;
        }
      }
    }

    print("No compatible characteristic found.");
    setState(() {
      isReading = false;
    });
  }

  Future<void> onReadPressed() async {
    final provider =
        Provider.of<BluetoothDeviceProvider>(context, listen: false);
    final device = provider.connectedDevice;
    if (device == null) {
      Snackbar.show(ABC.a, "No device connected", success: false);
      return;
    }
    await sendRequestAndReadResponse(device);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BluetoothDeviceProvider>(context);
    final connectedDevice = provider.connectedDevice;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: Text(widget.title,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bluetooth_backgroud.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StreamBuilder<BluetoothConnectionState>(
                stream: connectedDevice?.connectionState,
                builder: (context, snapshot) {
                  bool isConnected =
                      snapshot.data == BluetoothConnectionState.connected;
                  return Text(
                    isConnected
                        ? "Connected to: ${connectedDevice?.remoteId}"
                        : "No device connected",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isConnected ? Colors.green : Colors.red),
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ScanScreen())),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text("Connect a device",
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 20),
              if (connectedDevice != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onReadPressed,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: isReading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Read from ESP",
                          style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 20),
                Text("Packets received: ${receivedPackets.length}",
                    style: const TextStyle(fontSize: 16, color: Colors.black)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
