import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BLEConnectPage extends StatefulWidget {
  @override
  _BLEConnectPageState createState() => _BLEConnectPageState();
}

class _BLEConnectPageState extends State<BLEConnectPage> {
  //FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  BluetoothDevice? connectedDevice;
  List<BluetoothDevice> devicesList = [];
  BluetoothCharacteristic? targetCharacteristic;

  @override
  void initState() {
    super.initState();
    scanForDevices();
  }

  void scanForDevices() {
    FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (!devicesList.contains(r.device)) {
          setState(() {
            devicesList.add(r.device);
          });
        }
      }
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    await device.connect();
    setState(() {
      connectedDevice = device;
    });
    discoverServices(device);
  }

  void discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.write || characteristic.properties.read) {
          setState(() {
            targetCharacteristic = characteristic;
          });
        }
      }
    }
  }

  void sendData(String data) async {
    if (targetCharacteristic != null) {
      await targetCharacteristic!.write(data.codeUnits);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ESP32 BLE Connection")),
      body: connectedDevice == null
          ? ListView.builder(
              itemCount: devicesList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(devicesList[index].name.isNotEmpty
                      ? devicesList[index].name
                      : "Unknown Device"),
                  subtitle: Text(devicesList[index].id.toString()),
                  onTap: () => connectToDevice(devicesList[index]),
                );
              },
            )
          : Column(
              children: [
                Text("Connected to: ${connectedDevice!.name}"),
                TextField(
                  decoration: InputDecoration(labelText: "Enter data to send"),
                  onSubmitted: sendData,
                ),
              ],
            ),
    );
  }
}
