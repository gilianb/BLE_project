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
          // Envoyer "0" pour demander l'envoi des données
          if (characteristic.properties.write) {
            await characteristic
                .write([48], withoutResponse: false); // "0" en ASCII
            print("Commande '0' envoyée à l'ESP32");
          }

          // Lire la réponse
          if (characteristic.properties.notify) {
            characteristic.setNotifyValue(true);
            characteristic.onValueReceived.listen((List<int> data) {
              if (data.length < 3) return;

              int packetIndex = data[0] | (data[1] << 8);
              String receivedChunk = String.fromCharCodes(data.sublist(2));

              receivedPackets[packetIndex] = receivedChunk;
              print("Reçu paquet $packetIndex : $receivedChunk");

              if (totalPackets != -1 &&
                  receivedPackets.length == totalPackets) {
                List<MapEntry<int, String>> sortedEntries =
                    receivedPackets.entries.toList();
                sortedEntries.sort((a, b) => a.key.compareTo(b.key));

                String completeData =
                    sortedEntries.map((entry) => entry.value).join('');

                print("Donnée complète reconstruite : $completeData");
                setState(() {
                  isReading = false;
                });
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
    print("Aucune caractéristique compatible trouvée.");
    setState(() {
      isReading = false;
    });
  }

  Future<void> onReadPressed() async {
    final provider =
        Provider.of<BluetoothDeviceProvider>(context, listen: false);
    final device = provider.connectedDevice;
    if (device == null) {
      Snackbar.show(ABC.a, "Aucun appareil connecté", success: false);
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
              Text(
                connectedDevice != null
                    ? "Connecté à : ${connectedDevice.remoteId}"
                    : "Aucun appareil connecté",
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
                child: const Text("Connecter un appareil",
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
                      : const Text("Lire depuis ESP",
                          style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 20),
                Text("Paquets reçus : ${receivedPackets.length}",
                    style: const TextStyle(fontSize: 16, color: Colors.black)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
