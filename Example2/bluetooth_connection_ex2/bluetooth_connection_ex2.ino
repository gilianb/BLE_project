#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

BLEServer* pServer = NULL;
BLECharacteristic* pCharWrite = NULL;
BLECharacteristic* pCharNotify = NULL;
BLECharacteristic* pCharRead = NULL;

bool deviceConnected = false;
bool oldDeviceConnected = false;
bool readyToSend = false;
uint32_t value = 1;

// UUIDs for the service and characteristics
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_WRITE_UUID     "beb5483e-36e1-4688-b7f5-ea07361b26a8"  // For writing commands
#define CHAR_NOTIFY_UUID    "6d68efe5-04b6-4a85-abc4-c2670b7bf7fd"  // For sending notifications
#define CHAR_READ_UUID      "3c0f8a8a-2546-4c7e-87d7-bae8d29465fa"  // For simple reading

// Connection management
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("A device has connected.");
    };

    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        Serial.println("A device has disconnected.");
    }
};

// Handling data received from the application
class MyWriteCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        std::string value_from_app = pCharacteristic->getValue();
        if (value_from_app.length() > 0) {
            String receivedData = String(value_from_app.c_str());
            Serial.println("Data received from the application: " + receivedData);
            
            if (receivedData == "0") {
                readyToSend = true;
            }
        }
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("Starting BLE server...");

    // Initialize BLE
    BLEDevice::init("ESP32");

    // Create BLE server
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    // Create BLE service
    BLEService *pService = pServer->createService(SERVICE_UUID);

    // ✅ Characteristic for writing (receiving commands)
    pCharWrite = pService->createCharacteristic(
        CHAR_WRITE_UUID,
        BLECharacteristic::PROPERTY_WRITE
    );
    pCharWrite->setCallbacks(new MyWriteCallbacks());

    // ✅ Characteristic for sending notifications
    pCharNotify = pService->createCharacteristic(
        CHAR_NOTIFY_UUID,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pCharNotify->addDescriptor(new BLE2902());  // Enables notification

    // ✅ Characteristic for simple reading
    pCharRead = pService->createCharacteristic(
        CHAR_READ_UUID,
        BLECharacteristic::PROPERTY_READ
    );
    pCharRead->setValue("Initial value");

    // Start the service
    pService->start();

    // Start BLE advertising
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    BLEDevice::startAdvertising();

    Serial.println("BLE server ready and waiting for connections...");
}

void loop() {
    // Send notification if the application has requested data
    if (deviceConnected && readyToSend) {
        delay(100);
        pCharNotify->setValue((uint8_t*)&value, 4);
        pCharNotify->notify();
        Serial.println("Notification sent: " + String(value));
        int temperature = random(20, 30);
        String tempStr = "Temperature: " + String(temperature);
        pCharRead->setValue(tempStr.c_str());  
        pCharRead->notify();
        Serial.println("Temperature sent: " + tempStr);

        value++;  
        readyToSend = false;  
    }

    // Handle reconnection/disconnection
    if (!deviceConnected && oldDeviceConnected) {
        delay(500);
        pServer->startAdvertising();
        Serial.println("Restarting advertising...");
        oldDeviceConnected = deviceConnected;
    }

    if (deviceConnected && !oldDeviceConnected) {
        Serial.println("New connection established.");
        oldDeviceConnected = deviceConnected;
    }

    delay(100);
}
