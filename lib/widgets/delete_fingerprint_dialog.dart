import 'package:fingerprint_attendance/cubit/attendance_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeleteFingerprintDialog extends StatefulWidget {
  const DeleteFingerprintDialog({super.key});

  @override
  State<DeleteFingerprintDialog> createState() =>
      _DeleteFingerprintDialogState();
}

class _DeleteFingerprintDialogState extends State<DeleteFingerprintDialog> {
  final slotController = TextEditingController();

  @override
  void dispose() {
    slotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Fingerprint'),
      content: TextField(
        controller: slotController,
        decoration: const InputDecoration(
          labelText: 'Slot Number (1-127)',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final slot = int.tryParse(slotController.text);
            if (slot != null) {
              context.read<AttendanceCubit>().deleteFingerprint(slot);
              Navigator.pop(context);
            }
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
