import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

/// Repository for managing local storage of student names and attendance records.
///
/// Uses Hive boxes for storage:
/// - `students` box: Maps studentId -> studentName
/// - `attendance_YYYY-MM-DD` boxes: Maps studentId -> ISO DateTime string
class StorageRepository {
  static const String _studentsBoxName = 'students';
  static const String _attendancePrefix = 'attendance_';

  late Box<String> _studentsBox;

  Box<String> get studentsBox => _studentsBox;

  /// Initialize Hive and open the students box.
  Future<void> init() async {
    await Hive.initFlutter();
    _studentsBox = await Hive.openBox<String>(_studentsBoxName);
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

  /// Get all student names as a map.
  Map<String, String> getAllStudentNames() {
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
  }

  /// Get all attendance box names (for listing all attendance dates).
  Future<List<String>> getAllAttendanceDates() async {
    // This requires listing all boxes, which Hive doesn't directly support.
    // We would need to track this separately or scan the directory.
    // For now, return an empty list - this can be enhanced later.
    return [];
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await Hive.close();
  }
}
