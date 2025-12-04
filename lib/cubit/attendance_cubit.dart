import 'dart:async';

import 'package:fingerprint_attendance/cubit/attendance_state.dart';
import 'package:fingerprint_attendance/models/attendance_record.dart';
import 'package:fingerprint_attendance/models/student.dart';
import 'package:fingerprint_attendance/repositories/arduino_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  AttendanceCubit(this._repository)
      : super(const AttendanceStateDisconnected()) {
    _init();
  }

  final ArduinoRepository _repository;
  StreamSubscription<ArduinoResponse>? _responseSubscription;
  final List<AttendanceRecord> _records = [];
  final Map<String, Student> _students = {};

  Future<void> _init() async {
    final ports = await _repository.getAvailablePorts();

    emit(AttendanceStateDisconnected(availablePorts: ports));
  }

  Future<void> connect(String portName) async {
    emit(const AttendanceStateConnecting());

    final success = await _repository.connect(portName);
    if (success) {
      _responseSubscription = _repository.responses.listen(_handleResponse);
      emit(AttendanceStateConnected(records: _records, students: _students));
    } else {
      final ports = await _repository.getAvailablePorts();
      emit(AttendanceStateDisconnected(availablePorts: ports));
    }
  }

  void _handleResponse(ArduinoResponse response) {
    final currentState = state;
    if (currentState is! AttendanceStateConnected) return;

    switch (response) {
      case AttendanceTakenResponse():
        _records.add(
          AttendanceRecord(
            studentId: response.studentId,
            timestamp: DateTime.now(),
          ),
        );
        emit(
          currentState.copyWith(
            records: List.from(_records),
            message: 'Attendance recorded for ${response.studentId}',
            isProcessing: false,
          ),
        );

      case FingerprintEnrolledResponse():
        final student = Student(
          id: response.studentId,
          name: 'Student ${response.studentId}',
          slotNumber: response.slotNumber,
        );
        _students[response.studentId] = student;
        emit(
          currentState.copyWith(
            students: Map.from(_students),
            message: 'Fingerprint enrolled successfully',
            isProcessing: false,
          ),
        );

      case FingerprintDeletedResponse():
        final studentId = _students.entries
            .firstWhere(
              (e) => e.value.slotNumber == response.slotNumber,
              orElse: () =>
                  const MapEntry('', Student(id: '', name: '', slotNumber: 0)),
            )
            .key;
        if (studentId.isNotEmpty) {
          _students.remove(studentId);
        }
        emit(
          currentState.copyWith(
            students: Map.from(_students),
            message: 'Fingerprint deleted',
            isProcessing: false,
          ),
        );

      case FingerprintNotRecognizedResponse():
        emit(
          currentState.copyWith(
            message: 'Fingerprint not recognized',
            isProcessing: false,
          ),
        );

      case ErrorResponse():
        emit(
          currentState.copyWith(
            message: response.message,
            isProcessing: false,
          ),
        );
    }
  }

  Future<void> takeAttendance() async {
    final currentState = state;
    if (currentState is! AttendanceStateConnected) return;

    emit(currentState.copyWith(isProcessing: true, clearMessage: true));
    await _repository.sendCommand(const TakeAttendanceCommand());
  }

  Future<void> enrollFingerprint(int slotNumber, String studentId) async {
    final currentState = state;
    if (currentState is! AttendanceStateConnected) return;

    if (!_isValidSlotNumber(slotNumber)) {
      emit(
        currentState.copyWith(
          message: 'Invalid slot number. Must be between 1 and 127.',
        ),
      );
      return;
    }

    if (!_isValidStudentId(studentId)) {
      emit(
        currentState.copyWith(
          message: 'Student ID cannot be empty.',
        ),
      );
      return;
    }

    emit(currentState.copyWith(isProcessing: true, clearMessage: true));

    await _repository.sendCommand(
      EnrollFingerprintCommand(
        slotNumber: slotNumber,
        studentId: studentId,
      ),
    );
  }

  Future<void> deleteFingerprint(int slotNumber) async {
    final currentState = state;
    if (currentState is! AttendanceStateConnected) return;

    if (!_isValidSlotNumber(slotNumber)) {
      emit(
        currentState.copyWith(
          message: 'Invalid slot number. Must be between 1 and 127.',
        ),
      );
      return;
    }

    emit(currentState.copyWith(isProcessing: true, clearMessage: true));
    await _repository
        .sendCommand(DeleteFingerprintCommand(slotNumber: slotNumber));
  }

  bool _isValidSlotNumber(int slotNumber) {
    return slotNumber >= 1 && slotNumber <= 127;
  }

  bool _isValidStudentId(String studentId) {
    return studentId.trim().isNotEmpty;
  }

  void clearRecords() {
    final currentState = state;
    if (currentState is! AttendanceStateConnected) return;

    _records.clear();
    emit(
      currentState.copyWith(
        records: List.from(_records),
        message: 'Records cleared',
      ),
    );
  }

  void clearMessage() {
    final currentState = state;
    if (currentState is! AttendanceStateConnected) return;

    emit(currentState.copyWith(clearMessage: true));
  }

  @override
  Future<void> close() {
    _responseSubscription?.cancel();
    _repository.dispose();
    return super.close();
  }
}
