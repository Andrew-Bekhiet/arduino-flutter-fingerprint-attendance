import 'package:fingerprint_attendance/cubit/attendance_cubit.dart';
import 'package:fingerprint_attendance/cubit/attendance_state.dart';
import 'package:fingerprint_attendance/widgets/clear_records_dialog.dart';
import 'package:fingerprint_attendance/widgets/delete_fingerprint_dialog.dart';
import 'package:fingerprint_attendance/widgets/enroll_fingerprint_dialog.dart';
import 'package:fingerprint_attendance/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ControlPanel extends StatelessWidget {
  final AttendanceStateConnected state;

  const ControlPanel({required this.state, super.key});

  @override
  Widget build(BuildContext context) {
    final isProcessing = false ?? state.isProcessing;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Controls',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: isProcessing
                ? null
                : () => context.read<AttendanceCubit>().takeAttendance(),
            icon: const Icon(Icons.fingerprint),
            label: const Text('Take Attendance'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isProcessing
                ? null
                : () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) =>
                          const EnrollFingerprintDialog(),
                    ),
            icon: const Icon(Icons.person_add),
            label: const Text('Enroll Fingerprint'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isProcessing
                ? null
                : () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) =>
                          const DeleteFingerprintDialog(),
                    ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Fingerprint'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: state.records.isEmpty
                ? null
                : () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => const ClearRecordsDialog(),
                    ),
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear Records'),
          ),
          const Divider(height: 32),
          Text(
            'Statistics',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          StatCard(
            label: 'Total Records',
            value: state.totalRecordsCount.toString(),
            icon: Icons.event_note,
          ),
          const SizedBox(height: 8),
          StatCard(
            label: 'Enrolled Students',
            value: state.enrolledStudentsCount.toString(),
            icon: Icons.people,
          ),
          const SizedBox(height: 8),
          StatCard(
            label: "Today's Attendance",
            value: state.todayAttendanceCount.toString(),
            icon: Icons.today,
          ),
          if (state.isProcessing) ...[
            const Divider(height: 32),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              'Processing...',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
