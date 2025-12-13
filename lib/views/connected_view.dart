import 'package:fingerprint_attendance/cubit/attendance_state.dart';
import 'package:fingerprint_attendance/widgets/attendance_table.dart';
import 'package:fingerprint_attendance/widgets/control_panel.dart';
import 'package:flutter/material.dart';

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
