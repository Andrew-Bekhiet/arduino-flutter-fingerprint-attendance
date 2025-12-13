import 'dart:async';

import 'package:fingerprint_attendance/cubit/attendance_state.dart';
import 'package:fingerprint_attendance/models/attendance_record.dart';
import 'package:fingerprint_attendance/models/student.dart';
import 'package:fingerprint_attendance/repositories/arduino_models/arduino_command.dart';
import 'package:fingerprint_attendance/repositories/arduino_models/arduino_response.dart';
import 'package:fingerprint_attendance/repositories/arduino_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  final ArduinoRepository _arduinoRepo;
  StreamSubscription<ArduinoResponse>? _responseSubscription;

  final List<AttendanceRecord> _attendanceRecords = [];
  final Map<String, Student> _students = {};
  final Map<int, String> _slotToStudentId = {};

  AttendanceCubit(this._arduinoRepo)
      : super(const AttendanceStateDisconnected()) {
    _init();
  }

  Future<void> _init() async {
    final ports = await _arduinoRepo.getAvailablePorts();

    emit(AttendanceStateDisconnected(availablePorts: ports));
  }

  Future<void> connect(String portName) async {
    emit(const AttendanceStateConnecting());

    final success = await _arduinoRepo.connect(portName);
    if (success) {
      _responseSubscription = _arduinoRepo.responses.listen(_handleResponse);
      emit(
        AttendanceStateConnected(
          records: _attendanceRecords,
          students: _students,
        ),
      );
    } else {
      final ports = await _arduinoRepo.getAvailablePorts();
      emit(AttendanceStateDisconnected(availablePorts: ports));
    }
  }

  void _handleResponse(ArduinoResponse response) {
    final currentState = state;
    if (currentState is! AttendanceStateConnected) return;

    switch (response) {
      case ReadyResponse():
        emit(currentState.copyWith(message: 'Sensor ready'));

      case PlaceFingerResponse():
        emit(currentState.copyWith(message: 'Place finger on sensor...'));

      case RemoveFingerResponse():
        emit(currentState.copyWith(message: 'Remove finger'));

      case PlaceSameFingerResponse():
        emit(currentState.copyWith(message: 'Place same finger again...'));

      case FingerprintFoundResponse():
        final studentId = _slotToStudentId[response.slotNumber];

        if (studentId != null) {
          _attendanceRecords.add(
            AttendanceRecord(
              studentId: studentId,
              timestamp: DateTime.now(),
            ),
          );
          emit(
            currentState.copyWith(
              records: List.from(_attendanceRecords),
              message: 'Attendance recorded for $studentId',
              isProcessing: false,
            ),
          );
        } else {
          emit(
            currentState.copyWith(
              message: 'Fingerprint not registered in app',
              isProcessing: false,
            ),
          );
        }

      case FingerprintEnrolledResponse():
        final student = Student(
          id: response.studentId,
          name: 'Student ${response.studentId}',
          slotNumber: response.slotNumber,
        );
        _students[response.studentId] = student;
        _slotToStudentId[response.slotNumber] = response.studentId;

        emit(
          currentState.copyWith(
            students: Map.from(_students),
            message: 'Fingerprint enrolled successfully',
            isProcessing: false,
          ),
        );

      case FingerprintDeletedResponse():
        final studentId = _slotToStudentId.remove(response.slotNumber);

        if (studentId != null) {
          _students.remove(studentId);
        }

        emit(
          currentState.copyWith(
            students: {..._students},
            message: 'Fingerprint deleted',
            isProcessing: false,
          ),
        );

      case AllFingerprintsDeletedResponse():
        _slotToStudentId.clear();
        _students.clear();

        emit(
          currentState.copyWith(
            students: {..._students},
            message: 'All fingerprints deleted',
            isProcessing: false,
          ),
        );

      case FingerprintNotFoundResponse():
        emit(
          currentState.copyWith(
            message: 'Fingerprint not recognized',
            isProcessing: false,
          ),
        );

      case WarningResponse():
        emit(currentState.copyWith(message: response.message));

      case RetryResponse():
        emit(
          currentState.copyWith(
            message: 'Retrying... Attempt ${response.attemptNumber} of 3',
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
    await _arduinoRepo.sendCommand(const TakeAttendanceCommand());
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

    await _arduinoRepo.sendCommand(
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
    await _arduinoRepo
        .sendCommand(DeleteFingerprintCommand(slotNumber: slotNumber));
  }

  bool _isValidSlotNumber(int slotNumber) {
    return slotNumber >= 1 && slotNumber <= 127;
  }

  bool _isValidStudentId(String studentId) {
    return int.tryParse(studentId) != null;
  }

  void clearRecords() {
    final currentState = state;
    if (currentState is! AttendanceStateConnected) return;

    _attendanceRecords.clear();
    emit(
      currentState.copyWith(
        records: List.from(_attendanceRecords),
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
  Future<void> close() async {
    await _responseSubscription?.cancel();
    await _arduinoRepo.dispose();
    await super.close();
  }
}
