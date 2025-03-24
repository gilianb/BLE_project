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
  bool isReading = false;

  Future<void> sendRequestAndReadResponse(BluetoothDevice device) async {
    setState(() {
      isReading = true;
    });

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.characteristicUuid ==
            Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8")) {
          // Send "0" to request data
          if (characteristic.properties.write) {
            await characteristic
                .write([48], withoutResponse: false); // "0" in ASCII
            print("Command '0' sent to ESP32");
          }

          // Read the response
          if (characteristic.properties.notify) {
            characteristic.setNotifyValue(true);
            characteristic.onValueReceived.listen((List<int> data) {
              if (data.isNotEmpty) {
                setState(() {
                  receivedData = data[0]; // Read and update UI
                });
                print("Response received from ESP32: $receivedData");
              }
            });
          }
          setState(() {
            isReading = false;
          });
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
        height: double.infinity, // Ensures the container takes full height
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bluetooth_backgroud.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SizedBox.expand(
          // Expands `Column` to take full height
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                connectedDevice != null
                    ? "Connected to: ${connectedDevice.remoteId}"
                    : "No device connected",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: connectedDevice != null ? Colors.green : Colors.red),
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
                Text("Received data: $receivedData",
                    style: const TextStyle(fontSize: 16, color: Colors.black)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
