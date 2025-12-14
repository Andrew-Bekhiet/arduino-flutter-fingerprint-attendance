import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fingerprint_attendance/cubit/attendance_state.dart';
import 'package:fingerprint_attendance/models/attendance_record.dart';
import 'package:fingerprint_attendance/models/student.dart';
import 'package:fingerprint_attendance/repositories/arduino_models/arduino_command.dart';
import 'package:fingerprint_attendance/repositories/arduino_models/arduino_response.dart';
import 'package:fingerprint_attendance/repositories/arduino_repository.dart';
import 'package:fingerprint_attendance/repositories/storage_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  final ArduinoRepository _arduinoRepo;
  final StorageRepository _storageRepo;
  StreamSubscription<ArduinoResponse>? _responseSubscription;

  final List<AttendanceRecord> _attendanceRecords = [];
  final Map<String, Student> _students = {};

  // Temporary storage for pending enrollment
  String? _pendingStudentName;

  AttendanceCubit(this._arduinoRepo, this._storageRepo)
      : super(const AttendanceStateDisconnected()) {
    _init();
  }

  Future<void> _init([bool connectNow = true]) async {
    final ports = await _arduinoRepo.getAvailablePorts();

    if (connectNow && ports.length == 1) {
      await connect(ports.single);
    } else {
      emit(AttendanceStateDisconnected(availablePorts: ports));
    }
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
      await stream.firstWhere((state) => state is AttendanceStateConnected);
      // Sync enrolled fingerprints from Arduino EEPROM
      await loadEnrolledFingerprints();
    } else {
      final ports = await _arduinoRepo.getAvailablePorts();
      emit(AttendanceStateDisconnected(availablePorts: ports));
    }
  }

  Future<void> loadEnrolledFingerprints() async {
    final currentState = state;
    if (currentState is! AttendanceStateConnected) return;

    emit(currentState.copyWith(isProcessing: true, clearMessage: true));
    await _arduinoRepo.sendCommand(const ListEnrolledCommand());
  }

  Future<void> _handleResponse(ArduinoResponse response) async {
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

      case FingerprintFoundResponse(:final studentId, :final slotNumber):
        final attendanceAlreadyRecorded = _attendanceRecords.any(
          (record) =>
              record.studentId == studentId &&
              DateUtils.isSameDay(record.timestamp, DateTime.now()),
        );

        if (attendanceAlreadyRecorded) {
          emit(
            currentState.copyWith(
              message:
                  'Attendance already recorded for ${_students[studentId]?.name ?? studentId} today',
              isProcessing: false,
            ),
          );
          return;
        }

        final timestamp = DateTime.now();

        _attendanceRecords.add(
          AttendanceRecord(
            studentId: studentId,
            timestamp: timestamp,
          ),
        );

        // Record attendance in Hive storage
        await _storageRepo.recordAttendance(studentId, timestamp);

        // Also update local cache if we don't have this student
        if (!_students.containsKey(studentId)) {
          final studentName = _storageRepo.getStudentName(studentId);
          final student = Student(
            id: studentId,
            name: studentName ?? 'Student $studentId',
            slotNumber: slotNumber,
          );
          _students[studentId] = student;

          final current = state;
          if (current is AttendanceStateConnected) {
            emit(current.copyWith(students: Map.from(_students)));
          }
        }

        final displayName = _students[studentId]?.name ?? studentId;
        emit(
          currentState.copyWith(
            records: List.from(_attendanceRecords),
            students: Map.from(_students),
            message: 'Attendance recorded for $displayName',
            isProcessing: false,
          ),
        );

      case FingerprintEnrolledResponse(:final slotNumber, :final studentId):
        // Use pending name or default
        final studentName = _pendingStudentName ?? 'Student $studentId';
        _pendingStudentName = null;

        final student = Student(
          id: studentId,
          name: studentName,
          slotNumber: slotNumber,
        );
        _students[studentId] = student;

        // Save student name to Hive storage
        await _storageRepo.saveStudentName(studentId, studentName);

        emit(
          currentState.copyWith(
            students: Map.from(_students),
            message: 'Fingerprint enrolled for $studentName',
            isProcessing: false,
          ),
        );

      case FingerprintDeletedResponse(:final slotNumber):
        final MapEntry<String, Student>? studentEntry =
            _students.entries.firstWhereOrNull(
          (s) => s.value.slotNumber == slotNumber,
        );

        if (studentEntry != null) {
          _students.remove(studentEntry.key);

          final student = studentEntry.value;

          await _storageRepo.deleteStudentName(student.id);

          emit(
            currentState.copyWith(
              students: {..._students},
              message: 'Fingerprint deleted for ${student.name}',
              isProcessing: false,
            ),
          );
        } else {
          emit(
            currentState.copyWith(
              students: {..._students},
              message: 'Fingerprint deleted',
              isProcessing: false,
            ),
          );
        }

      case AllFingerprintsDeletedResponse():
        _students.clear();
        await _storageRepo.clearAllStudentNames();

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

      case ListStartResponse():
        _students.clear();
        emit(
          currentState.copyWith(message: 'Loading enrolled fingerprints...'),
        );

      case SlotInfoResponse(:final slotNumber, :final studentId):
        // Arduino sends enrolled fingerprint info from EEPROM
        // Try to load saved name from Hive storage
        final savedName = _storageRepo.getStudentName(studentId);
        final student = Student(
          id: studentId,
          name: savedName ?? 'Student $studentId',
          slotNumber: slotNumber,
        );
        _students[studentId] = student;

        final current = state;
        if (current is AttendanceStateConnected) {
          emit(current.copyWith(students: Map.from(_students)));
        }

      case ListEndResponse():
        emit(
          currentState.copyWith(
            students: Map.from(_students),
            message: 'Loaded ${_students.length} enrolled fingerprints',
            isProcessing: false,
          ),
        );

      case WarningResponse(:final message):
        emit(currentState.copyWith(message: message));

      case RetryResponse(:final attemptNumber):
        emit(
          currentState.copyWith(
            message: 'Retrying... Attempt $attemptNumber of 3',
          ),
        );

      case ErrorResponse(:final message):
        emit(
          currentState.copyWith(
            message: message,
            isProcessing: false,
          ),
        );
    }
  }

  Future<void> takeAttendance() async {
    final currentState = state;
    if (currentState is! AttendanceStateConnected) return;

    await _arduinoRepo.sendCommand(const TakeAttendanceCommand());
    emit(currentState.copyWith(isProcessing: true, clearMessage: true));
  }

  Future<void> enrollFingerprint(
    int slotNumber,
    String studentId, {
    String? studentName,
  }) async {
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

    // Store pending name for when enrollment completes
    _pendingStudentName = studentName;

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

  Future<void> deleteAllFingerprints() async {
    final currentState = state;
    if (currentState is! AttendanceStateConnected) return;

    emit(currentState.copyWith(isProcessing: true, clearMessage: true));
    await _arduinoRepo.sendCommand(const DeleteAllFingerprintsCommand());
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

  void _clearMessage(String message) {
    final currentState = state;
    if (currentState is! AttendanceStateConnected ||
        currentState.message != message) {
      return;
    }

    emit(currentState.copyWith(clearMessage: true));
  }

  @override
  void emit(AttendanceState state) {
    super.emit(state);

    if (state case AttendanceStateConnected(:final message?)
        when message.isNotEmpty) {
      Future.delayed(const Duration(seconds: 2))
          .then((_) => _clearMessage(message));
    }
  }

  @override
  Future<void> close() async {
    await _responseSubscription?.cancel();
    await _arduinoRepo.dispose();
    await super.close();
  }

  Future<void> disconnect() async {
    await _arduinoRepo.disconnect();
    await _init(false);
  }
}
