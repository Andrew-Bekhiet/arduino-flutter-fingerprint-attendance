import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fingerprint_attendance/repositories/arduino_models/arduino_command.dart';
import 'package:fingerprint_attendance/repositories/arduino_models/arduino_response.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class ArduinoRepository {
  SerialPort? _port;
  SerialPortReader? _portReader;
  StreamSubscription<Uint8List>? _readerSubscription;
  final _responseController = StreamController<ArduinoResponse>.broadcast();

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
        ..parity = SerialPortParity.none;

      port.config = config;

      final canControlArduino = port.openReadWrite();

      if (!canControlArduino) {
        return false;
      }

      _portReader = SerialPortReader(port);
      _readerSubscription = _portReader?.stream.listen(_handleData);

      _port = port;

      return true;
    } catch (e) {
      return false;
    }
  }

  void _handleData(Uint8List data) {
    final text = utf8.decode(data);

    final lines = text.split('\n');

    for (final line in lines) {
      if (line.trim().isNotEmpty) {
        _parseResponse(line.trim());
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
        final slotNumber = int.parse(line.replaceFirst('FOUND:', ''));

        _responseController.add(
          FingerprintFoundResponse(slotNumber: slotNumber),
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

      default:
        _responseController.add(
          ErrorResponse(message: 'Unknown response: $line'),
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

  void dispose() {
    _responseController.close();
    disconnect();
  }
}
