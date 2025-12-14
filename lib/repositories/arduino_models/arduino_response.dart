sealed class ArduinoResponse {
  const ArduinoResponse();
}

final class ReadyResponse extends ArduinoResponse {
  const ReadyResponse();
}

final class PlaceFingerResponse extends ArduinoResponse {
  const PlaceFingerResponse();
}

final class RemoveFingerResponse extends ArduinoResponse {
  const RemoveFingerResponse();
}

final class PlaceSameFingerResponse extends ArduinoResponse {
  const PlaceSameFingerResponse();
}

final class FingerprintEnrolledResponse extends ArduinoResponse {
  const FingerprintEnrolledResponse({
    required this.slotNumber,
    required this.studentId,
  });

  final int slotNumber;
  final String studentId;
}

final class FingerprintFoundResponse extends ArduinoResponse {
  const FingerprintFoundResponse({
    required this.slotNumber,
    required this.studentId,
  });

  final int slotNumber;
  final String studentId;
}

final class FingerprintDeletedResponse extends ArduinoResponse {
  const FingerprintDeletedResponse({required this.slotNumber});

  final int slotNumber;
}

final class AllFingerprintsDeletedResponse extends ArduinoResponse {
  const AllFingerprintsDeletedResponse();
}

final class FingerprintNotFoundResponse extends ArduinoResponse {
  const FingerprintNotFoundResponse();
}

final class ListStartResponse extends ArduinoResponse {
  const ListStartResponse();
}

final class ListEndResponse extends ArduinoResponse {
  const ListEndResponse();
}

final class SlotInfoResponse extends ArduinoResponse {
  const SlotInfoResponse({
    required this.slotNumber,
    required this.studentId,
  });

  final int slotNumber;
  final String studentId;
}

final class WarningResponse extends ArduinoResponse {
  const WarningResponse({required this.message});

  final String message;
}

final class RetryResponse extends ArduinoResponse {
  const RetryResponse({required this.attemptNumber});

  final int attemptNumber;
}

final class ErrorResponse extends ArduinoResponse {
  const ErrorResponse({required this.message});

  final String message;
}
