import 'package:equatable/equatable.dart';

final class AttendanceRecord extends Equatable {
  const AttendanceRecord({
    required this.studentId,
    required this.timestamp,
  });

  final String studentId;
  final DateTime timestamp;

  @override
  List<Object?> get props => [studentId, timestamp];
}
