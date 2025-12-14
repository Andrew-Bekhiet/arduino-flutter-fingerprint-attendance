import 'package:collection/collection.dart';
import 'package:fingerprint_attendance/models/attendance_record.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

/// Repository for managing local storage of student names and attendance records.
///
/// Uses Hive boxes for storage:
/// - `students` box: Maps studentId -> studentName
/// - `attendance_dates` box: Tracks all dates with attendance records
/// - `attendance_YYYY-MM-DD` boxes: Maps studentId -> ISO DateTime string
class StorageRepository {
  static const String _studentsBoxName = 'students';
  static const String _attendanceDatesBoxName = 'attendance_dates';
  static const String _attendancePrefix = 'attendance_';

  late Box<String> _studentsBox;
  late Box<String> _attendanceDatesBox;

  Box<String> get studentsBox => _studentsBox;
  Box<String> get attendanceDatesBox => _attendanceDatesBox;

  /// Initialize Hive and open the students and attendance dates boxes.
  Future<void> init() async {
    await Hive.initFlutter();
    _studentsBox = await Hive.openBox<String>(_studentsBoxName);
    _attendanceDatesBox = await Hive.openBox<String>(_attendanceDatesBoxName);
  }

  /// Get or create an attendance box for a specific date.
  Future<Box<String>> _getAttendanceBox(DateTime date) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final boxName = '$_attendancePrefix$dateKey';

    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<String>(boxName);
    }
    return Hive.openBox<String>(boxName);
  }

  // Student name operations

  /// Save a student's name.
  Future<void> saveStudentName(String studentId, String name) async {
    await studentsBox.put(studentId, name);
  }

  /// Get a student's name by ID.
  String? getStudentName(String studentId) {
    return studentsBox.get(studentId);
  }

  /// Get all student names as a map of id to name.
  Map<String, String> getStudentNamesById() {
    return Map<String, String>.from(studentsBox.toMap());
  }

  /// Delete a student's name.
  Future<void> deleteStudentName(String studentId) async {
    await studentsBox.delete(studentId);
  }

  /// Clear all student names.
  Future<void> clearAllStudentNames() async {
    await studentsBox.clear();
  }

  // Attendance operations

  /// Record attendance for a student.
  Future<void> recordAttendance(String studentId, DateTime timestamp) async {
    final box = await _getAttendanceBox(timestamp);
    final isoDateTime = timestamp.toIso8601String();
    await box.put(studentId, isoDateTime);

    // Track this date in the attendance dates box
    final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);
    if (!_attendanceDatesBox.containsKey(dateKey)) {
      await _attendanceDatesBox.put(dateKey, dateKey);
    }
  }

  /// Get attendance records for a specific date.
  Future<Map<String, DateTime>> getAttendanceForDate(DateTime date) async {
    final box = await _getAttendanceBox(date);

    return box
        .toMap()
        .map((key, value) => MapEntry(key.toString(), DateTime.parse(value)));
  }

  /// Get attendance records for today.
  Future<Map<String, DateTime>> getTodayAttendance() async {
    return getAttendanceForDate(DateTime.now());
  }

  /// Check if a student has attended today.
  Future<bool> hasAttendedToday(String studentId) async {
    final box = await _getAttendanceBox(DateTime.now());
    return box.get(studentId) != null;
  }

  /// Clear attendance records for a specific date.
  Future<void> clearAttendanceForDate(DateTime date) async {
    final box = await _getAttendanceBox(date);
    await box.clear();

    // Remove from attendance dates tracking
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    await _attendanceDatesBox.delete(dateKey);
  }

  /// Get all attendance dates that have records.
  List<DateTime> getAllAttendanceDates() {
    return _attendanceDatesBox.keys
        .map((key) => DateTime.parse(key.toString()))
        .sortedBy((d) => d)
        .toList();
  }

  /// Load all attendance records from all tracked dates.
  Future<List<AttendanceRecord>> loadAllAttendanceRecords() async {
    final allRecords = <AttendanceRecord>[];

    for (final dateKey in _attendanceDatesBox.keys) {
      final date = DateTime.parse(dateKey.toString());
      final box = await _getAttendanceBox(date);

      for (final entry in box.toMap().entries) {
        allRecords.add(
          AttendanceRecord(
            studentId: entry.key.toString(),
            timestamp: DateTime.parse(entry.value),
          ),
        );
      }
    }

    // Sort by timestamp, most recent first
    allRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allRecords;
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await Hive.close();
  }
}
