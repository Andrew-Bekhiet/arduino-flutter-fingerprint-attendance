import 'package:fingerprint_attendance/cubit/attendance_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ClearRecordsDialog extends StatelessWidget {
  const ClearRecordsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clear All Records'),
      content: const Text(
        'Are you sure you want to clear all attendance records? '
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            context.read<AttendanceCubit>().clearRecords();
            Navigator.pop(context);
          },
          child: const Text('Clear'),
        ),
      ],
    );
  }
}
