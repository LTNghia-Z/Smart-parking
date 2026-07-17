#include <WiFi.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ESP32Servo.h>

#include <Firebase_ESP_Client.h>

#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// ================= WIFI =================
#define WIFI_SSID "DUNG"
#define WIFI_PASSWORD "66668888"

// ================= FIREBASE =================
#define API_KEY "AIzaSyCPVadyMdGhk9gGjhpQbvJDaXXjFlv-39I"
#define DATABASE_URL "https://smart-parking-fd456-default-rtdb.asia-southeast1.firebasedatabase.app/"
#define FIREBASE_AUTH "RzRbOH3HNbx5lkH4cTrAGLTltCuH2XRUHLTis2pY "
#define FIREBASE_PROJECT_ID "smart-parking-fd456"

// ================= RFID =================
// RFID vào
#define SS_IN_PIN   5

// RFID ra
#define SS_OUT_PIN  4

// RST dùng chung
#define RST_PIN     22

MFRC522 rfidIn(5, 22);
MFRC522 rfidOut(SS_OUT_PIN, RST_PIN);

//Servo
Servo servoIn;
Servo servoOut;

#define SERVO_IN_PIN   12
#define SERVO_OUT_PIN  13

// ================= HC-SR04 =================
#define TRIG1 14
#define ECHO1 27

#define TRIG2 26
#define ECHO2 25

#define TRIG3 33
#define ECHO3 32
bool slotState[3] = {false, false, false};

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// String getUID(MFRC522 &reader)
// {
//     String uid = "";

//     for (byte i = 0; i < reader.uid.size; i++)
//     {
//         if (reader.uid.uidByte[i] < 0x10)
//             uid += "0";

//         uid += String(reader.uid.uidByte[i], HEX);
//     }

//     uid.toUpperCase();

//     return uid;
// }

// String getCurrentTime() {
//     struct tm timeinfo;
//     char timeString[25];

//     if (getLocalTime(&timeinfo)) {
//         strftime(timeString,
//                  sizeof(timeString),
//                  "%Y-%m-%d %H:%M:%S",
//                  &timeinfo);
//         return String(timeString);
//     }

//     return "Unknown";
// }

// void sendToRealtimeDB(String uid) {

//     FirebaseJson json;

//     Firebase.RTDB.setString(&fbdo, "/type", "quet_the");

//     json.set("uid", uid);
//     json.set("plate", "");
//     json.set("fix", "");
//     json.set("time", getCurrentTime());

//     if (Firebase.RTDB.setJSON(&fbdo, "/data", &json)) {
//         Serial.println("Gui Realtime Database thanh cong");
//     } else {
//         Serial.println(fbdo.errorReason());
//     }
// }

// void handleRFID(String uid, String timeString) {

//     FirebaseJson content;

//     content.set("fields/cardId/stringValue", uid);
//     content.set("fields/type/stringValue", "entry");
//     content.set("fields/status/stringValue", "waiting");
//     content.set("fields/licensePlate/stringValue", "");
//     content.set("fields/time/stringValue", timeString);

//     String documentPath = "parking_logs/" + uid + "_" + String(millis());

//     if (Firebase.Firestore.createDocument(
//         &fbdo,
//         FIREBASE_PROJECT_ID,
//         "",
//         documentPath.c_str(),
//         content.raw())) {

//     Serial.println("===== FIRESTORE =====");
//     Serial.println("Gui Firestore thanh cong");
//     Serial.println(fbdo.payload());
//     }
//     else {
//         Serial.println("===== FIRESTORE =====");
//         Serial.println(fbdo.errorReason());
//     }

// }

void setup() {
  Serial.begin(9600);

  // RFID
SPI.begin(18, 19, 23);

rfidIn.PCD_Init();
rfidOut.PCD_Init();

Serial.println("RFID IN Ready");
Serial.println("RFID OUT Ready");

//Servo
servoIn.attach(SERVO_IN_PIN);
servoOut.attach(SERVO_OUT_PIN);

//Cảm biến siêu âm HC-SR04
pinMode(TRIG1, OUTPUT);
pinMode(ECHO1, INPUT);

pinMode(TRIG2, OUTPUT);
pinMode(ECHO2, INPUT);

pinMode(TRIG3, OUTPUT);
pinMode(ECHO3, INPUT);

// Đóng cổng ban đầu
servoIn.write(0);
servoOut.write(0);

  // WIFI
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Dang ket noi WiFi");

  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }

  Serial.println();
  Serial.println("WiFi Connected");

  // Firebase
config.api_key = API_KEY;
config.database_url = DATABASE_URL;

if (Firebase.signUp(&config, &auth, "", "")) {
  Serial.println("Firebase SignUp OK");
} else {
  Serial.println(config.signer.signupError.message.c_str());
}

Firebase.begin(&config, &auth);
Firebase.reconnectWiFi(true);

  Serial.println("Firebase Ready");

//time
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 7 * 3600;
const int daylightOffset_sec = 0;

configTime(gmtOffset_sec, daylightOffset_sec, "pool.ntp.org");

struct tm timeinfo;

while (!getLocalTime(&timeinfo)) {
    Serial.println("Dang dong bo thoi gian...");
    delay(500);
}

Serial.println("Dong bo thoi gian thanh cong");
}

void loop() {
  rfidIn.PCD_Init();
  delay(100);
  rfidOut.PCD_Init();
  delay(100);
  
  checkOpenGate();

// ================= RFID CỔNG VÀO =================
if (rfidIn.PICC_IsNewCardPresent() && rfidIn.PICC_ReadCardSerial())
{
    String cid = getCID(rfidIn);

    Serial.println("====== CONG VAO ======");
    Serial.println(cid);

    sendToRealtimeDBIn(cid);


    rfidIn.PICC_HaltA();
    rfidIn.PCD_StopCrypto1();

    delay(500);
}

// ================= RFID CỔNG RA =================
if (rfidOut.PICC_IsNewCardPresent() && rfidOut.PICC_ReadCardSerial())
{
    String cid = getCID(rfidOut);

    Serial.println("====== CONG RA ======");
    Serial.println(cid);

    sendToRealtimeDBOut(cid);

    rfidOut.PICC_HaltA();
    rfidOut.PCD_StopCrypto1();

    delay(500);
}
  checkParkingSlots();
}