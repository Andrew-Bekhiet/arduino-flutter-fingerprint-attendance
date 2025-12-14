import 'package:collection/collection.dart';
import 'package:fingerprint_attendance/cubit/attendance_cubit.dart';
import 'package:fingerprint_attendance/cubit/attendance_state.dart';
import 'package:fingerprint_attendance/models/student.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeleteFingerprintDialog extends StatefulWidget {
  const DeleteFingerprintDialog({super.key});

  @override
  State<DeleteFingerprintDialog> createState() =>
      _DeleteFingerprintDialogState();
}

class _DeleteFingerprintDialogState extends State<DeleteFingerprintDialog> {
  Student? _selectedStudent;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceCubit, AttendanceState>(
      builder: (context, state) {
        if (state is! AttendanceStateConnected) {
          return const AlertDialog(
            title: Text('Delete Fingerprint'),
            content: Text('Not connected'),
          );
        }

        final students = state.students.values.sortedBy((s) => s.name);

        return AlertDialog(
          title: const Text('Delete Fingerprint'),
          content: SizedBox(
            width: double.maxFinite,
            child: students.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No enrolled fingerprints'),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select a student to delete:'),
                      const SizedBox(height: 12),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final isSelected =
                                _selectedStudent?.id == student.id;

                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              leading: CircleAvatar(
                                child: Text('${student.slotNumber}'),
                              ),
                              title: Text(student.name),
                              subtitle: Text('ID: ${student.id}'),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedStudent = student;
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _selectedStudent == null
                  ? null
                  : () {
                      context
                          .read<AttendanceCubit>()
                          .deleteFingerprint(_selectedStudent!.slotNumber);
                      Navigator.pop(context);
                    },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
