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
  final int slotNumber;
  final String studentId;

  const FingerprintEnrolledResponse({
    required this.slotNumber,
    required this.studentId,
  });
}

final class FingerprintFoundResponse extends ArduinoResponse {
  final int slotNumber;

  const FingerprintFoundResponse({required this.slotNumber});
}

final class FingerprintDeletedResponse extends ArduinoResponse {
  final int slotNumber;

  const FingerprintDeletedResponse({required this.slotNumber});
}

final class AllFingerprintsDeletedResponse extends ArduinoResponse {
  const AllFingerprintsDeletedResponse();
}

final class FingerprintNotFoundResponse extends ArduinoResponse {
  const FingerprintNotFoundResponse();
}

final class WarningResponse extends ArduinoResponse {
  final String message;

  const WarningResponse({required this.message});
}

final class RetryResponse extends ArduinoResponse {
  final int attemptNumber;

  const RetryResponse({required this.attemptNumber});
}

final class ErrorResponse extends ArduinoResponse {
  final String message;

  const ErrorResponse({required this.message});
}
