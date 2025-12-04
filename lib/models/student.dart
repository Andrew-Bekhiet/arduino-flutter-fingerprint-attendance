import 'package:equatable/equatable.dart';

final class Student extends Equatable {
  const Student({
    required this.id,
    required this.name,
    required this.slotNumber,
  });

  final String id;
  final String name;
  final int slotNumber;

  @override
  List<Object?> get props => [id, name, slotNumber];
}
