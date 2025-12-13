#include <Adafruit_Fingerprint.h>
#include <SoftwareSerial.h>

SoftwareSerial mySerial(2, 3);
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&mySerial);

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
  }
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
  String studentId = input.substring(secondColon + 1);

  if (slot < 1 || slot > 127)
  {
    Serial.println("ERROR:Invalid slot");
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
    Serial.print("FOUND:");
    Serial.println(finger.fingerID);
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
    Serial.println("DELETED_ALL");
  }
  else
  {
    Serial.println("ERROR:Delete all failed");
  }
}
