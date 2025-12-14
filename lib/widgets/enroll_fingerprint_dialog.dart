import 'package:fingerprint_attendance/cubit/attendance_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enroll Fingerprint'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Student Name',
              border: OutlineInputBorder(),
            ),
          ),
          TextField(
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            controller: idController,
            decoration: const InputDecoration(
              labelText: 'Student ID',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          TextField(
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            controller: slotController,
            decoration: const InputDecoration(
              labelText: 'Slot Number (1-127)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
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
            final name = nameController.text.trim();
            if (slot != null && id.isNotEmpty) {
              context.read<AttendanceCubit>().enrollFingerprint(
                    slot,
                    id,
                    studentName: name.isNotEmpty ? name : null,
                  );
              Navigator.pop(context);
            }
          },
          child: const Text('Enroll'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    slotController.dispose();
    idController.dispose();
    nameController.dispose();
    super.dispose();
  }
}
