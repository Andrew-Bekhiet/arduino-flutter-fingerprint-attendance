import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:fingerprint_attendance/models/attendance_record.dart';
import 'package:fingerprint_attendance/models/student.dart';
import 'package:flutter/material.dart';

sealed class AttendanceState with EquatableMixin {
  const AttendanceState();
}

final class AttendanceStateDisconnected extends AttendanceState {
  final List<String> availablePorts;

  const AttendanceStateDisconnected({this.availablePorts = const []});

  @override
  List<Object?> get props => [availablePorts];
}

final class AttendanceStateConnecting extends AttendanceState {
  const AttendanceStateConnecting();

  @override
  List<Object?> get props => [];
}

final class AttendanceStateConnected extends AttendanceState {
  final List<AttendanceRecord> records;
  final Map<String, Student> students;
  final String? message;
  final bool isProcessing;

  const AttendanceStateConnected({
    required this.records,
    required this.students,
    this.message,
    this.isProcessing = false,
  });

  List<AttendanceRecord> get sortedRecords =>
      records.sorted((a, b) => b.timestamp.compareTo(a.timestamp));

  int get todayAttendanceCount => records
      .where((record) => DateUtils.isSameDay(record.timestamp, DateTime.now()))
      .length;

  int get totalRecordsCount => records.length;
  int get enrolledStudentsCount => students.length;

  AttendanceStateConnected copyWith({
    List<AttendanceRecord>? records,
    Map<String, Student>? students,
    String? message,
    bool? isProcessing,
    bool clearMessage = false,
  }) {
    return AttendanceStateConnected(
      records: records ?? this.records,
      students: students ?? this.students,
      message: clearMessage ? null : (message ?? this.message),
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  @override
  List<Object?> get props => [records, students, message, isProcessing];
}

final class AttendanceStateError extends AttendanceState {
  final String message;

  const AttendanceStateError({required this.message});

  @override
  List<Object?> get props => [message];
}
