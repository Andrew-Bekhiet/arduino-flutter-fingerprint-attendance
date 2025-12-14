#include <Adafruit_Fingerprint.h>
#include <SoftwareSerial.h>
#include <EEPROM.h>

SoftwareSerial mySerial(2, 3);
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&mySerial);

// EEPROM Layout:
// Section 1 (0-511): Student ID mappings
//   Each slot (1-127) gets 4 bytes for studentId (32-bit unsigned integer)
//   Slot N starts at address: (N - 1) * 4
// Section 2 (512-513): Attendance record count (2 bytes)
// Section 3 (514+): Attendance records
//   Each record = 4 bytes timestamp + 16 bytes bitmask (128 bits for 127 slots)
//   Total per record = 20 bytes

const int STUDENT_ID_SIZE = 4;
const int MAX_SLOTS = 127;
const unsigned long MIN_STUDENT_ID = 100000000UL; // 9 digits min
const unsigned long MAX_STUDENT_ID = 999999999UL; // 9 digits max

// Attendance storage constants
const int ATTENDANCE_COUNT_ADDR = 512;      // 2 bytes for count
const int ATTENDANCE_RECORDS_START = 514;   // Records start here
const int ATTENDANCE_RECORD_SIZE = 20;      // 4 bytes timestamp + 16 bytes bitmask
const int BITMASK_SIZE = 16;                // 16 bytes = 128 bits (for slots 1-127)
const int MAX_ATTENDANCE_RECORDS = 50;      // Max records (limited by EEPROM size)

struct AttendanceRecord {
  unsigned long timestamp;                  // When record was created
  byte attendanceBitmask[BITMASK_SIZE];     // Bit N = slot N attended (1-127)
};

void setup()
{
  Serial.begin(9600);
  while (!Serial)
    ;
  delay(100);

  finger.begin(57600);

  while (!finger.verifyPassword())
  {
    Serial.println("ERROR:Sensor not found");
    delay(5000);
  }

  Serial.println("READY");
  printMenu();
}

void printMenu()
{
  Serial.println();
  Serial.println("=================================");
  Serial.println("  Fingerprint Attendance System  ");
  Serial.println("=================================");
  Serial.println();
  Serial.println("Available Commands:");
  Serial.println("  e:<slot>:<studentId> - Enroll fingerprint");
  Serial.println("                         slot: 1-127");
  Serial.println("                         studentId: 9 digits");
  Serial.println("  a                    - Take attendance");
  Serial.println("  d:<slot>             - Delete fingerprint");
  Serial.println("  x                    - Delete all fingerprints");
  Serial.println("  l                    - List enrolled fingerprints");
  Serial.println("  r                    - View attendance records");
  Serial.println("  c                    - Clear attendance records");
  Serial.println();
  Serial.println("=================================");
  Serial.println();
}

void loop()
{
  if (Serial.available() > 0)
  {
    String input = Serial.readStringUntil('\n');
    input.trim();

    if (input.length() == 0)
      return;

    char command = input.charAt(0);

    if (command == 'e')
    {
      handleEnroll(input);
    }
    else if (command == 'a')
    {
      handleAttendance();
    }
    else if (command == 'd')
    {
      handleDelete(input);
    }
    else if (command == 'x')
    {
      handleDeleteAll();
    }
    else if (command == 'l')
    {
      handleListEnrolled();
    }
    else if (command == 'r')
    {
      handleViewRecords();
    }
    else if (command == 'c')
    {
      handleClearRecords();
    }
  }
}

int getEepromAddress(int slot)
{
  return (slot - 1) * STUDENT_ID_SIZE;
}

void saveStudentId(int slot, unsigned long studentId)
{
  int addr = getEepromAddress(slot);

  // Store as 4 bytes (little-endian)
  for (int i = 0; i < 4; i++)
  {
    EEPROM.update(addr + i, (studentId >> (i * 8)) & 0xFF);
  }
}

unsigned long loadStudentId(int slot)
{
  int addr = getEepromAddress(slot);
  unsigned long studentId = 0;

  // Read 4 bytes (little-endian)
  for (int i = 0; i < 4; i++)
  {
    studentId |= ((unsigned long)EEPROM.read(addr + i)) << (i * 8);
  }

  return studentId;
}

void clearStudentId(int slot)
{
  int addr = getEepromAddress(slot);

  for (int i = 0; i < STUDENT_ID_SIZE; i++)
  {
    EEPROM.update(addr + i, 0);
  }
}

void clearAllStudentIds()
{
  for (int slot = 1; slot <= MAX_SLOTS; slot++)
  {
    clearStudentId(slot);
  }
}

bool isSlotEmpty(int slot)
{
  return loadStudentId(slot) == 0;
}

bool isValidStudentId(unsigned long studentId)
{
  return studentId >= MIN_STUDENT_ID && studentId <= MAX_STUDENT_ID;
}

// Attendance record functions
int getAttendanceCount()
{
  int count = EEPROM.read(ATTENDANCE_COUNT_ADDR) | (EEPROM.read(ATTENDANCE_COUNT_ADDR + 1) << 8);
  if (count < 0 || count > MAX_ATTENDANCE_RECORDS)
  {
    return 0;
  }
  return count;
}

void setAttendanceCount(int count)
{
  EEPROM.update(ATTENDANCE_COUNT_ADDR, count & 0xFF);
  EEPROM.update(ATTENDANCE_COUNT_ADDR + 1, (count >> 8) & 0xFF);
}

int getRecordAddress(int recordIndex)
{
  return ATTENDANCE_RECORDS_START + (recordIndex * ATTENDANCE_RECORD_SIZE);
}

bool saveAttendanceRecord(int slot)
{
  int count = getAttendanceCount();

  if (count >= MAX_ATTENDANCE_RECORDS)
  {
    return false;
  }

  int addr = getRecordAddress(count);
  unsigned long timestamp = millis() / 1000;

  // Write timestamp (4 bytes)
  for (int i = 0; i < 4; i++)
  {
    EEPROM.update(addr + i, (timestamp >> (i * 8)) & 0xFF);
  }

  // Initialize bitmask with the attending slot
  for (int i = 0; i < BITMASK_SIZE; i++)
  {
    EEPROM.update(addr + 4 + i, 0);
  }

  // Set the bit for this slot
  int byteIndex = (slot - 1) / 8;
  int bitIndex = (slot - 1) % 8;
  EEPROM.update(addr + 4 + byteIndex, (1 << bitIndex));

  setAttendanceCount(count + 1);
  return true;
}

bool addToLastRecord(int slot)
{
  int count = getAttendanceCount();

  if (count <= 0)
  {
    return false;
  }

  int addr = getRecordAddress(count - 1);
  int byteIndex = (slot - 1) / 8;
  int bitIndex = (slot - 1) % 8;

  byte currentByte = EEPROM.read(addr + 4 + byteIndex);
  currentByte |= (1 << bitIndex);
  EEPROM.update(addr + 4 + byteIndex, currentByte);

  return true;
}

bool hasAttendedInRecord(int recordIndex, int slot)
{
  int addr = getRecordAddress(recordIndex);
  int byteIndex = (slot - 1) / 8;
  int bitIndex = (slot - 1) % 8;

  byte currentByte = EEPROM.read(addr + 4 + byteIndex);
  return (currentByte >> bitIndex) & 1;
}

AttendanceRecord readAttendanceRecord(int recordIndex)
{
  AttendanceRecord record;
  int addr = getRecordAddress(recordIndex);

  // Read timestamp (4 bytes)
  record.timestamp = 0;
  for (int i = 0; i < 4; i++)
  {
    record.timestamp |= ((unsigned long)EEPROM.read(addr + i)) << (i * 8);
  }

  // Read bitmask (16 bytes)
  for (int i = 0; i < BITMASK_SIZE; i++)
  {
    record.attendanceBitmask[i] = EEPROM.read(addr + 4 + i);
  }

  return record;
}

int countAttendeesInRecord(int recordIndex)
{
  int count = 0;
  AttendanceRecord record = readAttendanceRecord(recordIndex);

  for (int slot = 1; slot <= MAX_SLOTS; slot++)
  {
    int byteIndex = (slot - 1) / 8;
    int bitIndex = (slot - 1) % 8;

    if ((record.attendanceBitmask[byteIndex] >> bitIndex) & 1)
    {
      count++;
    }
  }

  return count;
}

void clearAttendanceRecords()
{
  setAttendanceCount(0);
}

void handleViewRecords()
{
  int count = getAttendanceCount();

  Serial.println("RECORDS_START");
  Serial.print("COUNT:");
  Serial.println(count);

  for (int i = 0; i < count; i++)
  {
    AttendanceRecord record = readAttendanceRecord(i);
    int attendeeCount = countAttendeesInRecord(i);

    Serial.print("RECORD:");
    Serial.print(i + 1);
    Serial.print(":");
    Serial.print("Attende_Count:");
    Serial.print(attendeeCount);
    Serial.println(":");

    // List all slots that attended
    bool first = true;
    for (int slot = 1; slot <= MAX_SLOTS; slot++)
    {
      int byteIndex = (slot - 1) / 8;
      int bitIndex = (slot - 1) % 8;

      if ((record.attendanceBitmask[byteIndex] >> bitIndex) & 1)
      {
        unsigned long studentId = loadStudentId(slot);
        Serial.println(studentId);
        first = false;
      }
    }
    Serial.println();
  }

  Serial.println("RECORDS_END");
}

void handleClearRecords()
{
  clearAttendanceRecords();
  Serial.println("RECORDS_CLEARED");
}

unsigned long parseStudentId(String str)
{
  // Check length is exactly 9 digits
  if (str.length() != 9)
  {
    return 0;
  }

  // Check all characters are digits
  for (int i = 0; i < 9; i++)
  {
    if (!isDigit(str.charAt(i)))
    {
      return 0;
    }
  }

  // Convert to unsigned long
  return strtoul(str.c_str(), NULL, 10);
}

void handleListEnrolled()
{
  Serial.println("LIST_START");

  for (int slot = 1; slot <= MAX_SLOTS; slot++)
  {
    uint8_t p = finger.loadModel(slot);

    if (p == FINGERPRINT_OK)
    {
      unsigned long studentId = loadStudentId(slot);

      Serial.print("SLOT:");
      Serial.print(slot);
      Serial.print(":");
      Serial.println(studentId);
    }
  }

  Serial.println("LIST_END");
}

void handleEnroll(String input)
{
  int firstColon = input.indexOf(':');
  int secondColon = input.indexOf(':', firstColon + 1);

  if (firstColon == -1 || secondColon == -1)
  {
    Serial.println("ERROR:Invalid format");
    return;
  }

  int slot = input.substring(firstColon + 1, secondColon).toInt();
  String studentIdStr = input.substring(secondColon + 1);
  unsigned long studentId = parseStudentId(studentIdStr);

  if (slot < 1 || slot > 127)
  {
    Serial.println("ERROR:Invalid slot");
    return;
  }

  if (!isValidStudentId(studentId))
  {
    Serial.println("ERROR:Student ID must be exactly 9 digits");
    return;
  }

  int maxAttempts = 3;

  for (int attempt = 1; attempt <= maxAttempts; attempt++)
  {
    if (attempt > 1)
    {
      Serial.print("RETRY:");
      Serial.println(attempt);
    }

    Serial.println("PLACE_FINGER");

    int p = -1;
    unsigned long startTime = millis();

    while (p != FINGERPRINT_OK)
    {
      if (millis() - startTime > 30000)
      {
        Serial.println("WARN:Timeout waiting for finger");
        if (attempt < maxAttempts)
          continue;
        Serial.println("ERROR:Enrollment failed after max attempts");
        return;
      }
      p = finger.getImage();
      if (p == FINGERPRINT_NOFINGER)
        continue;
      if (p != FINGERPRINT_OK)
      {
        Serial.println("WARN:Image capture failed, try again");
        break;
      }
    }

    if (p != FINGERPRINT_OK)
      continue;

    p = finger.image2Tz(1);
    if (p != FINGERPRINT_OK)
    {
      Serial.println("WARN:First template failed, try again");
      continue;
    }

    Serial.println("REMOVE_FINGER");
    delay(2000);

    p = 0;
    startTime = millis();
    while (p != FINGERPRINT_NOFINGER)
    {
      if (millis() - startTime > 10000)
      {
        Serial.println("WARN:Please remove finger");
        startTime = millis();
      }
      p = finger.getImage();
    }

    Serial.println("PLACE_SAME_FINGER");
    startTime = millis();

    while (p != FINGERPRINT_OK)
    {
      if (millis() - startTime > 30000)
      {
        Serial.println("WARN:Timeout waiting for finger");
        break;
      }
      p = finger.getImage();
      if (p == FINGERPRINT_NOFINGER)
        continue;
      if (p != FINGERPRINT_OK)
      {
        Serial.println("WARN:Image capture failed");
        break;
      }
    }

    if (p != FINGERPRINT_OK)
      continue;

    p = finger.image2Tz(2);
    if (p != FINGERPRINT_OK)
    {
      Serial.println("WARN:Second template failed, try again");
      continue;
    }

    p = finger.createModel();
    if (p == FINGERPRINT_ENROLLMISMATCH)
    {
      Serial.println("WARN:Fingerprints did not match, try again");
      continue;
    }
    if (p != FINGERPRINT_OK)
    {
      Serial.println("WARN:Model creation failed, try again");
      continue;
    }

    p = finger.storeModel(slot);
    if (p == FINGERPRINT_OK)
    {
      // Save studentId to EEPROM as 4-byte integer
      saveStudentId(slot, studentId);

      Serial.print("ENROLLED:");
      Serial.print(slot);
      Serial.print(":");
      Serial.println(studentId);
      return;
    }
    else
    {
      Serial.println("WARN:Storage failed, try again");
      continue;
    }
  }

  Serial.println("ERROR:Enrollment failed after max attempts");
}

void handleAttendance()
{
  Serial.println("PLACE_FINGER");

  unsigned long startTime = millis();
  int p = -1;

  while (p != FINGERPRINT_OK)
  {
    unsigned long timeEllapsed = millis() - startTime;

    bool isTimeout = timeEllapsed > 30 * 1000;
    if (isTimeout)
    {
      Serial.println("ERROR:Timeout");
      return;
    }

    p = finger.getImage();
    if (p == FINGERPRINT_NOFINGER)
    {
      continue;
    }
    else if (p != FINGERPRINT_OK)
    {
      Serial.println("ERROR:Image failed");
      return;
    }
  }

  p = finger.image2Tz();
  if (p != FINGERPRINT_OK)
  {
    Serial.println("ERROR:Conversion failed");
    return;
  }

  p = finger.fingerSearch();
  if (p == FINGERPRINT_OK)
  {
    int slot = finger.fingerID;
    unsigned long studentId = loadStudentId(slot);

    // Add to last record or create new one
    bool saved = addToLastRecord(slot);
    if (!saved)
    {
      saved = saveAttendanceRecord(slot);
    }

    Serial.print("FOUND:");
    Serial.print(slot);
    Serial.print(":");
    Serial.print(studentId);
    Serial.print(":");
    Serial.println(saved ? "SAVED" : "MEMORY_FULL");
  }
  else if (p == FINGERPRINT_NOTFOUND)
  {
    Serial.println("NOT_FOUND");
  }
  else
  {
    Serial.println("ERROR:Search failed");
  }
}

void handleDelete(String input)
{
  int colonPos = input.indexOf(':');
  if (colonPos == -1)
  {
    Serial.println("ERROR:Invalid format");
    return;
  }

  int slot = input.substring(colonPos + 1).toInt();

  if (slot < 1 || slot > 127)
  {
    Serial.println("ERROR:Invalid slot");
    return;
  }

  if (finger.deleteModel(slot) == FINGERPRINT_OK)
  {
    // Clear studentId from EEPROM
    clearStudentId(slot);

    Serial.print("DELETED:");
    Serial.println(slot);
  }
  else
  {
    Serial.println("ERROR:Delete failed");
  }
}

void handleDeleteAll()
{
  if (finger.emptyDatabase() == FINGERPRINT_OK)
  {
    // Clear all studentIds from EEPROM
    clearAllStudentIds();

    Serial.println("DELETED_ALL");
  }
  else
  {
    Serial.println("ERROR:Delete all failed");
  }
}
