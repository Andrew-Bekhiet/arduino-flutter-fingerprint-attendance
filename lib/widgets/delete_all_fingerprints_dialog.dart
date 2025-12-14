import 'package:fingerprint_attendance/cubit/attendance_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeleteAllFingerprintsDialog extends StatelessWidget {
  const DeleteAllFingerprintsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete All Fingerprints'),
      content: const Text(
        'Are you sure you want to delete all enrolled fingerprints? '
        'This will remove all fingerprints from the sensor and clear all student data. '
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () {
            context.read<AttendanceCubit>().deleteAllFingerprints();
            Navigator.pop(context);
          },
          child: const Text('Delete All'),
        ),
      ],
    );
  }
}
