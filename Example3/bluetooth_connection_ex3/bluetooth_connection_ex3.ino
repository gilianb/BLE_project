#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;
bool readyToSend = false;
bool totalPacketsSent = false;  // New variable to track if totalPackets has been sent

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

const char* largeData = "Bluetooth Low Energy (BLE) has strict limitations on the amount of data that can be sent in a single transmission. To send a large piece of data, it must be broken down into smaller packets that fit within BLE's Maximum Transmission Unit (MTU). Each packet is assigned an index to ensure they are received in the correct order. The receiving device then reconstructs the original data by reassembling these packets."; 
int packetSize = 17;
int totalPackets;
int currentPacket = 0;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("A device has connected.");
    };

    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        totalPacketsSent = false;  // Reset state on disconnect
        Serial.println("A device has disconnected.");
    }
};

class MyCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        std::string value_from_app = pCharacteristic->getValue();
        
        if (value_from_app == "0") { // Trigger data send
            readyToSend = true;
            currentPacket = 0;
            totalPackets = (strlen(largeData) + packetSize - 1) / packetSize;
            totalPacketsSent = false;
            Serial.println("Preparing to send packets...");
        }
        else if (value_from_app == "ACK") { // The app has received totalPackets
            totalPacketsSent = true;
            Serial.println("The app confirmed the receipt of totalPackets.");
        }
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("Starting BLE server...");

    BLEDevice::init("ESP32");
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    BLEService *pService = pServer->createService(SERVICE_UUID);
    pCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_WRITE |
        BLECharacteristic::PROPERTY_NOTIFY |
        BLECharacteristic::PROPERTY_INDICATE
    );

    pCharacteristic->setCallbacks(new MyCallbacks());
    pService->start();
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    BLEDevice::startAdvertising();

    Serial.println("BLE server is ready and waiting for connections...");
}

void loop() {
    if (deviceConnected && readyToSend) {
        if (!totalPacketsSent) {
            // Send the total number of packets before the data
            char totalPacketsBuffer[2];
            totalPacketsBuffer[0] = totalPackets & 0xFF;
            totalPacketsBuffer[1] = (totalPackets >> 8) & 0xFF;
            pCharacteristic->setValue((uint8_t*)totalPacketsBuffer, 2);
            pCharacteristic->notify();
            Serial.println("Sending the total number of packets to the app...");
            delay(200);  // Small pause to avoid overwhelming the connection
        }
        else if (currentPacket < totalPackets) {
            // Send the data packets
            char buffer[packetSize + 2]; // 2 bytes for the packet number
            buffer[0] = currentPacket & 0xFF; // Packet index (low byte)
            buffer[1] = (currentPacket >> 8) & 0xFF; // Packet index (high byte)
            strncpy(buffer + 2, largeData + (currentPacket * packetSize), packetSize);
            buffer[packetSize + 2] = '\0';
            pCharacteristic->setValue((uint8_t*)buffer, packetSize + 2);
            pCharacteristic->notify();
            
            Serial.print("Sending packet ");
            Serial.print(currentPacket);
            Serial.print(" : ");
            Serial.println(buffer + 2);

            currentPacket++;
            delay(100);  // Delay to avoid flooding the BLE channel
        }
    }

    // Handle disconnection
    if (!deviceConnected && oldDeviceConnected) {
        delay(500);
        pServer->startAdvertising();
        Serial.println("Restarting BLE advertising...");
        oldDeviceConnected = deviceConnected;
    }

    // Handle reconnection
    if (deviceConnected && !oldDeviceConnected) {
        Serial.println("New connection established.");
        oldDeviceConnected = deviceConnected;
    }

    delay(100);
}
