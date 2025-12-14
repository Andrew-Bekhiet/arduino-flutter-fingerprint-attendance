import 'package:collection/collection.dart';
import 'package:fingerprint_attendance/cubit/attendance_cubit.dart';
import 'package:fingerprint_attendance/cubit/attendance_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EnrolledStudentsDialog extends StatelessWidget {
  const EnrolledStudentsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: const Text('Enrolled Students'),
      content: SizedBox(
        width: screenSize.longestSide * 0.75,
        child: BlocBuilder<AttendanceCubit, AttendanceState>(
          builder: (context, state) {
            if (state is! AttendanceStateConnected) {
              return const Text('Not connected');
            }

            final students = state.students.values
                .sortedBy<num>((s) => s.slotNumber)
                .toList();

            if (students.isEmpty) {
              return const Text('No enrolled fingerprints');
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];

                return ListTile(
                  leading: CircleAvatar(
                    child: Text('${student.slotNumber}'),
                  ),
                  title: Text(student.name),
                  subtitle: Text('ID: ${student.id}'),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Close'),
        ),
      ],
    );
  }
}
