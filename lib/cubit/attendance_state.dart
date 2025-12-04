import 'package:equatable/equatable.dart';
import 'package:fingerprint_attendance/models/attendance_record.dart';
import 'package:fingerprint_attendance/models/student.dart';

sealed class AttendanceState with EquatableMixin {
  const AttendanceState();
}

final class AttendanceStateDisconnected extends AttendanceState {
  const AttendanceStateDisconnected({this.availablePorts = const []});

  final List<String> availablePorts;

  @override
  List<Object?> get props => [availablePorts];
}

final class AttendanceStateConnecting extends AttendanceState {
  const AttendanceStateConnecting();

  @override
  List<Object?> get props => [];
}

final class AttendanceStateConnected extends AttendanceState {
  const AttendanceStateConnected({
    required this.records,
    required this.students,
    this.message,
    this.isProcessing = false,
  });

  final List<AttendanceRecord> records;
  final Map<String, Student> students;
  final String? message;
  final bool isProcessing;

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
  const AttendanceStateError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
