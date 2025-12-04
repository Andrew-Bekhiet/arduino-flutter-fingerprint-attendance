#include <Adafruit_Fingerprint.h>
#include <SoftwareSerial.h>
#include <EEPROM.h>

// Connect R307 TX to Arduino pin 2, RX to Arduino pin 3
SoftwareSerial mySerial(2, 3);
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&mySerial);

// EEPROM structure
// Address 0-1: Number of stored records (max 50)
// Address 2+: Records (each record = 14 bytes: 4 for ID + 10 for timestamp)
const int MAX_RECORDS = 50;
const int RECORD_SIZE = 14;
const int RECORDS_START = 2;

struct AttendanceRecord {
  long studentID;
  unsigned long timestamp;
  byte day;
  byte month;
};

void setup() {
  Serial.begin(9600);
  while (!Serial);
  delay(100);
  
  Serial.println("\n=== Fingerprint Attendance System ===");
  
  // Start fingerprint sensor
  finger.begin(57600);
  
  if (finger.verifyPassword()) {
    Serial.println("Sensor connected!");
  } else {
    Serial.println("Sensor not found. Check wiring!");
    while (1) { delay(1); }
  }
  
  Serial.println("\nCommands:");
  Serial.println("'e' - Enroll new fingerprint");
  Serial.println("'a' - Take attendance");
  Serial.println("'v' - View attendance records");
  Serial.println("'c' - Clear attendance records");
  Serial.println("'d' - Delete fingerprint\n");
}

void loop() {
  if (Serial.available() > 0) {
    char command = Serial.read();
    
    if (command == 'e') {
      enrollFingerprint();
    } else if (command == 'a') {
      takeAttendance();
    } else if (command == 'v') {
      viewRecords();
    } else if (command == 'c') {
      clearRecords();
    } else if (command == 'd') {
      deleteFingerprint();
    }
  }
}

void enrollFingerprint() {
  Serial.println("\n--- Enroll New Fingerprint ---");
  Serial.println("Enter slot number (1-127):");
  
  int slot = readNumber();
  if (slot == 0) return;
  
  Serial.println("Enter 9-digit Student ID (e.g., 231600170):");
  long studentID = readLongNumber();
  if (studentID == 0) return;
  
  Serial.print("Enrolling Student ID: ");
  Serial.print(studentID);
  Serial.print(" in slot #");
  Serial.println(slot);
  
  if (getFingerprintEnroll(slot) == FINGERPRINT_OK) {
    // Store student ID mapping in EEPROM
    saveStudentIDMapping(slot, studentID);
  }
}

void takeAttendance() {
  Serial.println("\n--- Attendance Mode ---");
  Serial.println("Place finger on sensor...");
  
  int slot = getFingerprintID();
  
  if (slot > 0) {
    long studentID = getStudentIDFromSlot(slot);
    
    if (studentID > 0) {
      // Save to EEPROM
      if (saveAttendanceRecord(studentID)) {
        Serial.print("✓ PRESENT - Student ID: ");
        Serial.print(studentID);
        Serial.print(" - ");
        printCurrentTime();
        Serial.println("(Saved to memory)");
      } else {
        Serial.println("✗ Memory full! View and clear records.");
      }
    } else {
      Serial.println("✗ Student ID not found for this fingerprint!");
    }
  } else if (slot == FINGERPRINT_NOTFOUND) {
    Serial.println("✗ Fingerprint not recognized!");
  } else {
    Serial.println("✗ Error reading fingerprint");
  }
  
  delay(2000);
}

void viewRecords() {
  Serial.println("\n=== Attendance Records ===");
  
  int count = getRecordCount();
  
  if (count == 0) {
    Serial.println("No records found.");
    return;
  }
  
  Serial.print("Total records: ");
  Serial.print(count);
  Serial.print("/");
  Serial.println(MAX_RECORDS);
  Serial.println("---");
  
  for (int i = 0; i < count; i++) {
    AttendanceRecord record = readRecord(i);
    
    Serial.print(i + 1);
    Serial.print(". ID: ");
    Serial.print(record.studentID);
    Serial.print(" | Day: ");
    Serial.print(record.day);
    Serial.print(" | Month: ");
    Serial.print(record.month);
    Serial.print(" | Time: ");
    printTimestamp(record.timestamp);
  }
}

void clearRecords() {
  Serial.println("\n--- Clear Attendance Records ---");
  Serial.println("Type 'YES' to confirm:");
  
  String confirm = "";
  while (confirm.length() < 3) {
    if (Serial.available()) {
      char c = Serial.read();
      if (c != '\n' && c != '\r') {
        confirm += c;
      }
    }
  }
  
  if (confirm == "YES") {
    EEPROM.write(0, 0);
    EEPROM.write(1, 0);
    Serial.println("✓ All attendance records cleared!");
  } else {
    Serial.println("Cancelled");
  }
}

void deleteFingerprint() {
  Serial.println("\n--- Delete Fingerprint ---");
  Serial.println("Enter slot to delete (1-127):");
  
  int slot = readNumber();
  if (slot == 0) return;
  
  uint8_t p = finger.deleteModel(slot);
  
  if (p == FINGERPRINT_OK) {
    // Clear student ID mapping
    saveStudentIDMapping(slot, 0);
    Serial.print("✓ Deleted slot #");
    Serial.println(slot);
  } else {
    Serial.println("✗ Error deleting fingerprint");
  }
}

// EEPROM Functions
void saveStudentIDMapping(int slot, long studentID) {
  // Store mapping at address 512+ (leaving 0-511 for attendance)
  int addr = 512 + (slot * 4);
  EEPROM.put(addr, studentID);
}

long getStudentIDFromSlot(int slot) {
  int addr = 512 + (slot * 4);
  long studentID;
  EEPROM.get(addr, studentID);
  return studentID;
}

bool saveAttendanceRecord(long studentID) {
  int count = getRecordCount();
  
  if (count >= MAX_RECORDS) {
    return false;
  }
  
  AttendanceRecord record;
  record.studentID = studentID;
  record.timestamp = millis() / 1000;
  record.day = 3; // You can manually set this or add RTC
  record.month = 12;
  
  int addr = RECORDS_START + (count * RECORD_SIZE);
  EEPROM.put(addr, record);
  
  // Update count
  count++;
  EEPROM.write(0, count & 0xFF);
  EEPROM.write(1, (count >> 8) & 0xFF);
  
  return true;
}

AttendanceRecord readRecord(int index) {
  AttendanceRecord record;
  int addr = RECORDS_START + (index * RECORD_SIZE);
  EEPROM.get(addr, record);
  return record;
}

int getRecordCount() {
  int count = EEPROM.read(0) | (EEPROM.read(1) << 8);
  return count;
}

// Fingerprint Functions
uint8_t getFingerprintEnroll(int slot) {
  int p = -1;
  Serial.println("Place finger...");
  
  while (p != FINGERPRINT_OK) {
    p = finger.getImage();
    if (p == FINGERPRINT_NOFINGER) continue;
    if (p != FINGERPRINT_OK) return p;
  }
  
  p = finger.image2Tz(1);
  if (p != FINGERPRINT_OK) return p;
  
  Serial.println("Remove finger");
  delay(2000);
  
  p = 0;
  while (p != FINGERPRINT_NOFINGER) {
    p = finger.getImage();
  }
  
  Serial.println("Place same finger again...");
  while (p != FINGERPRINT_OK) {
    p = finger.getImage();
    if (p == FINGERPRINT_NOFINGER) continue;
    if (p != FINGERPRINT_OK) return p;
  }
  
  p = finger.image2Tz(2);
  if (p != FINGERPRINT_OK) return p;
  
  p = finger.createModel();
  if (p != FINGERPRINT_OK) return p;
  
  p = finger.storeModel(slot);
  if (p == FINGERPRINT_OK) {
    Serial.println("✓ Fingerprint enrolled successfully!");
  }
  
  return p;
}

int getFingerprintID() {
  uint8_t p = finger.getImage();
  if (p != FINGERPRINT_OK) return -1;
  
  p = finger.image2Tz();
  if (p != FINGERPRINT_OK) return -1;
  
  p = finger.fingerSearch();
  if (p == FINGERPRINT_OK) {
    return finger.fingerID;
  } else {
    return -2;
  }
}

// Helper Functions
int readNumber() {
  int num = 0;
  while (num == 0) {
    if (Serial.available()) {
      num = Serial.parseInt();
      if (num < 1 || num > 127) {
        Serial.println("Invalid! Enter 1-127:");
        num = 0;
      }
    }
  }
  return num;
}

long readLongNumber() {
  long num = 0;
  while (num == 0) {
    if (Serial.available()) {
      num = Serial.parseInt();
      if (num < 100000000 || num > 999999999) {
        Serial.println("Invalid! Enter 9-digit ID:");
        num = 0;
      }
    }
  }
  return num;
}

void printCurrentTime() {
  unsigned long seconds = millis() / 1000;
  printTimestamp(seconds);
}

void printTimestamp(unsigned long seconds) {
  unsigned long minutes = seconds / 60;
  unsigned long hours = minutes / 60;
  
  Serial.print("Time: ");
  if (hours < 10) Serial.print("0");
  Serial.print(hours);
  Serial.print(":");
  if ((minutes % 60) < 10) Serial.print("0");
  Serial.print(minutes % 60);
  Serial.print(":");
  if ((seconds % 60) < 10) Serial.print("0");
  Serial.println(seconds % 60);
}
