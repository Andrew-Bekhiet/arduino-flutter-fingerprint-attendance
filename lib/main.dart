import 'package:fingerprint_attendance/cubit/attendance_cubit.dart';
import 'package:fingerprint_attendance/cubit/attendance_state.dart';
import 'package:fingerprint_attendance/repositories/arduino_repository.dart';
import 'package:fingerprint_attendance/widgets/clear_records_dialog.dart';
import 'package:fingerprint_attendance/widgets/delete_fingerprint_dialog.dart';
import 'package:fingerprint_attendance/widgets/enroll_fingerprint_dialog.dart';
import 'package:fingerprint_attendance/widgets/error_view.dart';
import 'package:fingerprint_attendance/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AttendanceCubit(ArduinoRepository()),
      child: MaterialApp(
        title: 'Fingerprint Attendance Tracker',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const AttendanceScreen(),
      ),
    );
  }
}

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fingerprint Attendance Tracker'),
        elevation: 2,
      ),
      body: BlocConsumer<AttendanceCubit, AttendanceState>(
        listener: (context, state) {
          // Uses pattern matching
          // ignore: prefer_early_return
          if (state case AttendanceStateConnected(:final message?)) {
            final cubit = context.read<AttendanceCubit>();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                duration: const Duration(seconds: 2),
              ),
            );

            Future.delayed(const Duration(seconds: 2), cubit.clearMessage);
          }
        },
        builder: (context, state) => switch (state) {
          AttendanceStateDisconnected() => DisconnectedView(state: state),
          AttendanceStateConnecting() => const ConnectingView(),
          AttendanceStateConnected() => ConnectedView(state: state),
          AttendanceStateError() => ErrorView(state: state),
        },
      ),
    );
  }
}

class DisconnectedView extends StatelessWidget {
  const DisconnectedView({required this.state, super.key});

  final AttendanceStateDisconnected state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.usb_off,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Connect to Arduino',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (state.availablePorts.isEmpty)
                const Text('No serial ports available')
              else
                ...state.availablePorts.map(
                  (port) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: FilledButton.icon(
                      onPressed: () =>
                          context.read<AttendanceCubit>().connect(port),
                      icon: const Icon(Icons.usb),
                      label: Text(port),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectingView extends StatelessWidget {
  const ConnectingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Connecting to Arduino...'),
        ],
      ),
    );
  }
}

class ConnectedView extends StatelessWidget {
  const ConnectedView({required this.state, super.key});

  final AttendanceStateConnected state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: ControlPanel(state: state),
        ),
        Expanded(
          child: AttendanceTable(state: state),
        ),
      ],
    );
  }
}

class ControlPanel extends StatelessWidget {
  const ControlPanel({required this.state, super.key});

  final AttendanceStateConnected state;

  @override
  Widget build(BuildContext context) {
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
            onPressed: state.isProcessing
                ? null
                : () => context.read<AttendanceCubit>().takeAttendance(),
            icon: const Icon(Icons.fingerprint),
            label: const Text('Take Attendance'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: state.isProcessing
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
            onPressed: state.isProcessing
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

class AttendanceTable extends StatelessWidget {
  const AttendanceTable({required this.state, super.key});

  final AttendanceStateConnected state;

  @override
  Widget build(BuildContext context) {
    if (state.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No attendance records yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.table_chart,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'Attendance Records',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Student ID')),
                  DataColumn(label: Text('Student Name')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Time')),
                ],
                rows: state.sortedRecords.asMap().entries.map((entry) {
                  final index = entry.key;
                  final record = entry.value;
                  final student = state.students[record.studentId];
                  final dateFormat = DateFormat('MMM dd, yyyy');
                  final timeFormat = DateFormat('hh:mm:ss a');

                  return DataRow(
                    cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(Text(record.studentId)),
                      DataCell(Text(student?.name ?? 'Unknown')),
                      DataCell(Text(dateFormat.format(record.timestamp))),
                      DataCell(Text(timeFormat.format(record.timestamp))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
