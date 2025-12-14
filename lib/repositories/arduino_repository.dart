import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:fingerprint_attendance/repositories/arduino_models/arduino_command.dart';
import 'package:fingerprint_attendance/repositories/arduino_models/arduino_response.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class ArduinoRepository {
  SerialPort? _port;
  SerialPortReader? _portReader;
  StreamSubscription<Uint8List>? _readerSubscription;
  final _responseController = StreamController<ArduinoResponse>.broadcast();
  String _buffer = '';

  void _log(String message) {
    developer.log(message, name: 'ArduinoRepository');
  }

  Stream<ArduinoResponse> get responses => _responseController.stream;

  Future<List<String>> getAvailablePorts() async {
    return SerialPort.availablePorts;
  }

  Future<bool> connect(String portName) async {
    try {
      final port = SerialPort(portName);

      final config = SerialPortConfig()
        ..baudRate = 9600
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none
        ..dtr = SerialPortDtr.on
        ..rts = SerialPortRts.on;

      port.config = config;

      final canControlArduino = port.openReadWrite();

      if (!canControlArduino) {
        _log('Failed to open port: ${SerialPort.lastError}');
        return false;
      }

      _log('Port opened successfully: $portName');

      _portReader = SerialPortReader(port);
      _readerSubscription = _portReader?.stream.listen(
        _handleData,
        onError: (error) {
          _log('Stream error: $error');
          _responseController
              .add(ErrorResponse(message: 'Serial error: $error'));
        },
        onDone: () {
          _log('Stream closed');
        },
      );

      _port = port;

      return true;
    } catch (e) {
      _log('Connection error: $e');
      return false;
    }
  }

  void _handleData(Uint8List data) {
    _log('Received raw data: ${data.length} bytes');
    final text = utf8.decode(data);
    _log('Decoded text: $text');
    _buffer += text;

    final lines = _buffer.split('\n');
    _buffer = lines.last;

    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        _log('Parsing line: $line');
        _parseResponse(line);
      }
    }
  }

  void _parseResponse(String line) {
    switch (line) {
      case 'READY':
        _responseController.add(
          const ReadyResponse(),
        );

      case 'PLACE_FINGER':
        _responseController.add(
          const PlaceFingerResponse(),
        );

      case 'REMOVE_FINGER':
        _responseController.add(
          const RemoveFingerResponse(),
        );

      case 'PLACE_SAME_FINGER':
        _responseController.add(
          const PlaceSameFingerResponse(),
        );

      case 'NOT_FOUND':
        _responseController.add(
          const FingerprintNotFoundResponse(),
        );

      case 'DELETED_ALL':
        _responseController.add(
          const AllFingerprintsDeletedResponse(),
        );

      case 'LIST_START':
        _responseController.add(
          const ListStartResponse(),
        );

      case 'LIST_END':
        _responseController.add(
          const ListEndResponse(),
        );

      case _ when line.startsWith('ENROLLED:'):
        final parts = line.replaceFirst('ENROLLED:', '').split(':');

        final slotNumber = int.parse(parts[0]);
        final studentId = parts[1];

        _responseController.add(
          FingerprintEnrolledResponse(
            slotNumber: slotNumber,
            studentId: studentId,
          ),
        );

      case _ when line.startsWith('FOUND:'):
        final parts = line.replaceFirst('FOUND:', '').split(':');
        final slotNumber = int.parse(parts[0]);
        final studentId = parts[1];

        _responseController.add(
          FingerprintFoundResponse(
            slotNumber: slotNumber,
            studentId: studentId,
          ),
        );

      case _ when line.startsWith('SLOT:'):
        final parts = line.replaceFirst('SLOT:', '').split(':');
        final slotNumber = int.parse(parts[0]);
        final studentId = parts[1];

        _responseController.add(
          SlotInfoResponse(
            slotNumber: slotNumber,
            studentId: studentId,
          ),
        );

      case _ when line.startsWith('DELETED:'):
        final slotNumber = int.parse(line.replaceFirst('DELETED:', ''));

        _responseController.add(
          FingerprintDeletedResponse(slotNumber: slotNumber),
        );

      case _ when line.startsWith('WARN:'):
        _responseController.add(
          WarningResponse(message: line.replaceFirst('WARN:', '')),
        );

      case _ when line.startsWith('RETRY:'):
        final attempt = int.tryParse(line.replaceFirst('RETRY:', '')) ?? 0;

        _responseController.add(
          RetryResponse(attemptNumber: attempt),
        );

      case _ when line.startsWith('ERROR:'):
        _responseController.add(
          ErrorResponse(message: line.replaceFirst('ERROR:', '')),
        );
    }
  }

  Future<void> sendCommand(ArduinoCommand command) async {
    final port = _port;
    if (port == null || !port.isOpen) {
      throw Exception('Port not connected');
    }

    final data = utf8.encode('${command.command}\n');
    port.write(Uint8List.fromList(data));
  }

  Future<void> disconnect() async {
    await _readerSubscription?.cancel();
    _portReader?.close();
    _port?.close();
    _port?.dispose();
    _port = null;
  }

  Future<void> dispose() async {
    await _responseController.close();
    await disconnect();
  }
}
