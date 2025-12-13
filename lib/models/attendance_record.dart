import 'package:equatable/equatable.dart';

final class AttendanceRecord extends Equatable {
  final String studentId;
  final DateTime timestamp;

  @override
  List<Object?> get props => [studentId, timestamp];

  const AttendanceRecord({
    required this.studentId,
    required this.timestamp,
  });
}
