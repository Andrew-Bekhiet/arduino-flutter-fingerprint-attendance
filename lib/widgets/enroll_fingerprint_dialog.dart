import 'package:fingerprint_attendance/cubit/attendance_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EnrollFingerprintDialog extends StatefulWidget {
  const EnrollFingerprintDialog({super.key});

  @override
  State<EnrollFingerprintDialog> createState() =>
      _EnrollFingerprintDialogState();
}

class _EnrollFingerprintDialogState extends State<EnrollFingerprintDialog> {
  final slotController = TextEditingController();
  final idController = TextEditingController();

  @override
  void dispose() {
    slotController.dispose();
    idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enroll Fingerprint'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: slotController,
            decoration: const InputDecoration(
              labelText: 'Slot Number (1-127)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: idController,
            decoration: const InputDecoration(
              labelText: 'Student ID',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final slot = int.tryParse(slotController.text);
            final id = idController.text;
            if (slot != null && slot >= 1 && slot <= 127 && id.isNotEmpty) {
              context.read<AttendanceCubit>().enrollFingerprint(slot, id);
              Navigator.pop(context);
            }
          },
          child: const Text('Enroll'),
        ),
      ],
    );
  }
}
