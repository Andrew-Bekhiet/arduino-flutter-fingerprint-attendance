import 'package:fingerprint_attendance/cubit/attendance_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceTable extends StatelessWidget {
  final AttendanceStateConnected state;

  const AttendanceTable({required this.state, super.key});

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
