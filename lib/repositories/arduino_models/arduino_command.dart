sealed class ArduinoCommand {
  String get command;

  const ArduinoCommand();
}

final class EnrollFingerprintCommand extends ArduinoCommand {
  final int slotNumber;
  final String studentId;

  @override
  String get command => 'e:$slotNumber:$studentId';

  const EnrollFingerprintCommand({
    required this.slotNumber,
    required this.studentId,
  });
}

final class TakeAttendanceCommand extends ArduinoCommand {
  @override
  String get command => 'a';

  const TakeAttendanceCommand();
}

final class DeleteFingerprintCommand extends ArduinoCommand {
  final int slotNumber;

  @override
  String get command => 'd:$slotNumber';

  const DeleteFingerprintCommand({required this.slotNumber});
}

final class DeleteAllFingerprintsCommand extends ArduinoCommand {
  const DeleteAllFingerprintsCommand();

  @override
  String get command => 'x';
}

final class ListEnrolledCommand extends ArduinoCommand {
  const ListEnrolledCommand();

  @override
  String get command => 'l';
}
