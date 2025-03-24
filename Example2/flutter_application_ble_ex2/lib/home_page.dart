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
  int receivedData = 0;
  String readValue = "N/A";
  bool isReading = false;

  // UUIDs corresponding to ESP32 characteristics
  final Guid serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  final Guid charWriteUuid = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");
  final Guid charNotifyUuid = Guid("6d68efe5-04b6-4a85-abc4-c2670b7bf7fd");
  final Guid charReadUuid = Guid("3c0f8a8a-2546-4c7e-87d7-bae8d29465fa");

  Future<void> sendCommand(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.serviceUuid == serviceUuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.characteristicUuid == charWriteUuid &&
              characteristic.properties.write) {
            await characteristic
                .write([48], withoutResponse: false); // "0" in ASCII
            print("Command '0' sent to ESP32");
          }
        }
      }
    }
  }

  Future<void> readValueFromESP(BluetoothDevice device) async {
    setState(() {
      isReading = true;
    });

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.serviceUuid == serviceUuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.characteristicUuid == charReadUuid &&
              characteristic.properties.read) {
            List<int> value = await characteristic.read();
            setState(() {
              readValue = String.fromCharCodes(value);
            });
            print("Value read from ESP32: $readValue");
          }
        }
      }
    }
    setState(() {
      isReading = false;
    });
  }

  Future<void> listenForNotifications(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.serviceUuid == serviceUuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.characteristicUuid == charNotifyUuid &&
              characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            print("Notification enabled for ESP32");
            characteristic.onValueReceived.listen((List<int> data) {
              setState(() {
                receivedData = data[0]; // Read and update UI
              });
              print("Notification received from ESP32: $receivedData");
            });
          }
        }
      }
    }
  }

  Future<void> onReadPressed() async {
    final provider =
        Provider.of<BluetoothDeviceProvider>(context, listen: false);
    final device = provider.connectedDevice;
    if (device == null) {
      Snackbar.show(ABC.a, "No device connected", success: false);
      return;
    }

    await sendCommand(device);
    await listenForNotifications(device);
    await readValueFromESP(device);
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
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg_temp.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              connectedDevice != null
                  ? "✅ Connected to: ${connectedDevice.remoteId}"
                  : "❌ No device connected",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: connectedDevice != null
                    ? Colors.greenAccent
                    : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const ScanScreen())),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text("🔍 Connect a device",
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            const SizedBox(height: 20),
            if (connectedDevice != null) ...[
              ElevatedButton(
                onPressed: onReadPressed,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: isReading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("📡 Read from ESP",
                        style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
              const SizedBox(height: 30),

              // ✅ Card for received notifications
              Card(
                color: Colors.blueGrey[900]?.withOpacity(0.8),
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      const Text(
                        "📨 Received Data (Notification):",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "$receivedData",
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.yellowAccent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ✅ Card for direct read value
              Card(
                color: Colors.blueGrey[800]?.withOpacity(0.8),
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      const Text(
                        "📖 Read Value (Direct Read):",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "$readValue°C",
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyanAccent),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
