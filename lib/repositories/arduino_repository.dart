import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

sealed class ArduinoCommand {
  const ArduinoCommand();
  String get command;
}

final class EnrollFingerprintCommand extends ArduinoCommand {
  const EnrollFingerprintCommand({
    required this.slotNumber,
    required this.studentId,
  });

  final int slotNumber;
  final String studentId;

  @override
  String get command => 'e:$slotNumber:$studentId';
}

final class TakeAttendanceCommand extends ArduinoCommand {
  const TakeAttendanceCommand();

  @override
  String get command => 'a';
}

final class DeleteFingerprintCommand extends ArduinoCommand {
  const DeleteFingerprintCommand({required this.slotNumber});

  final int slotNumber;

  @override
  String get command => 'd:$slotNumber';
}

sealed class ArduinoResponse {
  const ArduinoResponse();
}

final class FingerprintEnrolledResponse extends ArduinoResponse {
  const FingerprintEnrolledResponse({
    required this.slotNumber,
    required this.studentId,
  });

  final int slotNumber;
  final String studentId;
}

final class AttendanceTakenResponse extends ArduinoResponse {
  const AttendanceTakenResponse({required this.studentId});

  final String studentId;
}

final class FingerprintDeletedResponse extends ArduinoResponse {
  const FingerprintDeletedResponse({required this.slotNumber});

  final int slotNumber;
}

final class ErrorResponse extends ArduinoResponse {
  const ErrorResponse({required this.message});

  final String message;
}

final class FingerprintNotRecognizedResponse extends ArduinoResponse {
  const FingerprintNotRecognizedResponse();
}

class ArduinoRepository {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _subscription;
  final _responseController = StreamController<ArduinoResponse>.broadcast();
  String _buffer = '';
  final Map<int, String> _slotToStudentId = {};

  Stream<ArduinoResponse> get responses => _responseController.stream;

  Future<List<String>> getAvailablePorts() async {
    return SerialPort.availablePorts;
  }

  Future<bool> connect(String portName) async {
    try {
      _port = SerialPort(portName);

      final config = SerialPortConfig()
        ..baudRate = 9600
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none;

      _port!.config = config;

      if (!_port!.openReadWrite()) {
        return false;
      }

      _reader = SerialPortReader(_port!);
      _subscription = _reader!.stream.listen(_handleData);

      return true;
    } catch (e) {
      return false;
    }
  }

  void _handleData(Uint8List data) {
    final text = utf8.decode(data);
    _buffer += text;

    final lines = _buffer.split('\n');
    _buffer = lines.last;

    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        _parseResponse(line);
      }
    }
  }

  void _parseResponse(String line) {
    if (line.startsWith('ENROLLED:')) {
      final parts = line.substring(9).split(':');
      if (parts.length == 2) {
        final slotNumber = int.parse(parts[0]);
        final studentId = parts[1];
        _slotToStudentId[slotNumber] = studentId;
        _responseController.add(
          FingerprintEnrolledResponse(
            slotNumber: slotNumber,
            studentId: studentId,
          ),
        );
      }
    } else if (line.startsWith('FOUND:')) {
      final slotNumber = int.parse(line.substring(6));
      final studentId = _slotToStudentId[slotNumber];
      if (studentId != null) {
        _responseController.add(AttendanceTakenResponse(studentId: studentId));
      } else {
        _responseController
            .add(const ErrorResponse(message: 'Student ID not found'));
      }
    } else if (line.startsWith('DELETED:')) {
      final slotNumber = int.parse(line.substring(8));
      _slotToStudentId.remove(slotNumber);
      _responseController
          .add(FingerprintDeletedResponse(slotNumber: slotNumber));
    } else if (line.startsWith('ERROR:')) {
      _responseController.add(ErrorResponse(message: line.substring(6)));
    } else if (line.contains('NOT FOUND')) {
      _responseController.add(const FingerprintNotRecognizedResponse());
    }
  }

  Future<void> sendCommand(ArduinoCommand command) async {
    if (_port == null || !_port!.isOpen) {
      throw Exception('Port not connected');
    }

    final data = utf8.encode('${command.command}\n');
    _port!.write(Uint8List.fromList(data));
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _reader?.close();
    _port?.close();
    _port?.dispose();
    _port = null;
  }

  void dispose() {
    _responseController.close();
    disconnect();
  }
}
