String getCID(MFRC522 &reader)
{
    String cid = "";

    for (byte i = 0; i < reader.uid.size; i++)
    {
        if (reader.uid.uidByte[i] < 0x10)
            cid += "0";

        cid += String(reader.uid.uidByte[i], HEX);
    }

    cid.toUpperCase();

    return cid;
}

String getCurrentTime() {
    struct tm timeinfo;
    char timeString[25];

    if (getLocalTime(&timeinfo)) {
        strftime(timeString,
                 sizeof(timeString),
                 "%Y-%m-%d %H:%M:%S",
                 &timeinfo);
        return String(timeString);
    }

    return "Unknown";
}

void sendToRealtimeDBIn(String cid) {

    FirebaseJson json;

    Firebase.RTDB.setString(&fbdo, "/type", "quet_vao");

    json.set("cid", cid);
    json.set("plate", "");
    json.set("fix", "");
    json.set("time", getCurrentTime());

    if (Firebase.RTDB.setJSON(&fbdo, "/data", &json)) {
        Serial.println("Gui Realtime Database thanh cong");
    } else {
        Serial.println(fbdo.errorReason());
    }
}

void sendToRealtimeDBOut(String cid) {

    FirebaseJson json;

    Firebase.RTDB.setString(&fbdo, "/type", "quet_ra");

    json.set("cid", cid);
    json.set("plate", "");
    json.set("fix", "");
    json.set("time", getCurrentTime());

    if (Firebase.RTDB.setJSON(&fbdo, "/data", &json)) {
        Serial.println("Gui Realtime Database thanh cong");
    } else {
        Serial.println(fbdo.errorReason());
    }
}

// void handleRFIDIn(String uid, String timeString) {

//     FirebaseJson content;

//     content.set("fields/cardId/stringValue", uid);
//     content.set("fields/type/stringValue", "entry");
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
// void handleRFIDOut(String uid, String timeString) {

//     FirebaseJson content;

//     content.set("fields/cardId/stringValue", uid);
//     content.set("fields/type/stringValue", "exit");
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

void saveRealtimeToFirestoreIn(String gateType) {

    FirebaseJson json;

    if (!Firebase.RTDB.getJSON(&fbdo, "/data")) {
        Serial.println(fbdo.errorReason());
        return;
    }

    json = fbdo.jsonObject();

    FirebaseJsonData result;

    String cid, plate, fix, time;

    json.get(result, "cid");
    cid = result.stringValue;

    json.get(result, "plate");
    plate = result.stringValue;

    json.get(result, "fix");
    fix = result.stringValue;

    json.get(result, "time");
    time = result.stringValue;

    FirebaseJson content;

    content.set("fields/cid/stringValue", cid);
    content.set("fields/plate/stringValue", plate);
    content.set("fields/fix/stringValue", fix);
    content.set("fields/time/stringValue", time);
    content.set("fields/state/stringValue", "1");

    String doc = "parking_logs/" + cid + "_" + String(millis());

    if (Firebase.Firestore.createDocument(
            &fbdo,
            FIREBASE_PROJECT_ID,
            "",
            doc.c_str(),
            content.raw())) {

        Serial.println("===== FIRESTORE =====");
        Serial.println("Luu Firestore thanh cong");
    }
    else {
        Serial.println(fbdo.errorReason());
    }
}

void saveRealtimeToFirestoreOut(String gateType) {

    FirebaseJson json;

    if (!Firebase.RTDB.getJSON(&fbdo, "/data")) {
        Serial.println(fbdo.errorReason());
        return;
    }

    json = fbdo.jsonObject();

    FirebaseJsonData result;

    String cid, plate, fix, time;

    json.get(result, "cid");
    cid = result.stringValue;

    json.get(result, "plate");
    plate = result.stringValue;

    json.get(result, "fix");
    fix = result.stringValue;

    json.get(result, "time");
    time = result.stringValue;

    FirebaseJson content;

    content.set("fields/cid/stringValue", cid);
    content.set("fields/plate/stringValue", plate);
    content.set("fields/fix/stringValue", fix);
    content.set("fields/time/stringValue", time);
    content.set("fields/state/stringValue", "0");

    String doc = "parking_logs/" + cid + "_" + String(millis());

    if (Firebase.Firestore.createDocument(
            &fbdo,
            FIREBASE_PROJECT_ID,
            "",
            doc.c_str(),
            content.raw())) {

        Serial.println("===== FIRESTORE =====");
        Serial.println("Luu Firestore thanh cong");
    }
    else {
        Serial.println(fbdo.errorReason());
    }
}

void checkOpenGate() {

    if (!Firebase.RTDB.getString(&fbdo, "/type")) {
        Serial.println(fbdo.errorReason());
        return;
    }

    String type = fbdo.stringData();

    if (type == "mo_cong_vao") {

        Serial.println("Co yeu cau mo cong vao");
        servoIn.write(90);
        saveRealtimeToFirestoreIn(type);
        Firebase.RTDB.setString(&fbdo, "/type", "da_luu");

    }if (type == "mo_cong_ra") {

        Serial.println("Co yeu cau mo cong ra");
        servoOut.write(90); 
        saveRealtimeToFirestoreOut(type);
        Firebase.RTDB.setString(&fbdo, "/type", "da_luu");
    }
    if (type == "dong_cong_vao") {

        Serial.println("Co yeu cau dong cong ra");
        servoOut.write(0);
    }
    if (type == "dong_cong_ra") {

        Serial.println("Co yeu cau dong cong ra");
        servoOut.write(0);
    }

}

float readDistance(int trigPin, int echoPin)
{
    digitalWrite(trigPin, LOW);
    delayMicroseconds(2);

    digitalWrite(trigPin, HIGH);
    delayMicroseconds(10);
    digitalWrite(trigPin, LOW);

    long duration = pulseIn(echoPin, HIGH, 30000);

    if (duration == 0)
        return 999;

    return duration * 0.0343 / 2.0;
}

void checkParkingSlots()
{
    float d1 = readDistance(TRIG1, ECHO1);
    bool s1 = d1 < 10;

    if (s1 != slotState[0])
    {
        slotState[0] = s1;
        sendParkingStatus(1, s1);
    }

    float d2 = readDistance(TRIG2, ECHO2);
    bool s2 = d2 < 10;

    if (s2 != slotState[1])
    {
        slotState[1] = s2;
        sendParkingStatus(2, s2);
    }

    float d3 = readDistance(TRIG3, ECHO3);
    bool s3 = d3 < 10;

    if (s3 != slotState[2])
    {
        slotState[2] = s3;
        sendParkingStatus(3, s3);
    }
}

void sendParkingStatus(int slot, bool occupied)
{
    FirebaseJson json;

    Firebase.RTDB.setString(&fbdo, "/type", "parking");

    json.set("slot", slot);
    json.set("occupied", occupied);

    if (Firebase.RTDB.setJSON(&fbdo, "/data", &json))
    {
        Serial.printf("Slot %d : %s\n",
                      slot,
                      occupied ? "Occupied" : "Empty");
    }
    else
    {
        Serial.println(fbdo.errorReason());
    }
}