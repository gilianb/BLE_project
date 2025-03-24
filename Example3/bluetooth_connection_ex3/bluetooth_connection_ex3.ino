#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool readyToSend = false;  

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

const char* largeData = "Ceci est un message très long que nous devons découper en plusieurs paquets pour l'envoyer via BLE."; 
int packetSize = 10;
int totalPackets;
int currentPacket = 0;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("Appareil connecté.");
    };

    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        Serial.println("Appareil déconnecté.");
    }
};

class MyCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        std::string value_from_app = pCharacteristic->getValue();
        
        if (value_from_app == "0") { // Déclencher l'envoi
            readyToSend = true;
            currentPacket = 0;
            totalPackets = (strlen(largeData) + packetSize - 1) / packetSize;
            Serial.println("Début de l'envoi de la grande donnée.");
        }
    }
};

void setup() {
    Serial.begin(115200);
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
}

void loop() {
    if (deviceConnected && readyToSend && currentPacket < totalPackets) {
        char buffer[packetSize + 2]; // 2 octets pour le numéro de paquet
        buffer[0] = currentPacket & 0xFF; // Index du paquet (octet bas)
        buffer[1] = (currentPacket >> 8) & 0xFF; // Index du paquet (octet haut)
        strncpy(buffer + 2, largeData + (currentPacket * packetSize), packetSize);
        buffer[packetSize + 2] = '\0';
        delay(100); // Délai pour éviter d'inonder le canal BLE
        pCharacteristic->setValue((uint8_t*)buffer, packetSize + 2);
        pCharacteristic->notify();
        
        Serial.print("Envoi du paquet ");
        Serial.print(currentPacket);
        Serial.print(" : ");
        Serial.println(buffer + 2);

        currentPacket++;
        delay(100); // Délai pour éviter d'inonder le canal BLE
    }
}
