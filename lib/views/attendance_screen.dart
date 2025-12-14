import 'package:fingerprint_attendance/cubit/attendance_cubit.dart';
import 'package:fingerprint_attendance/cubit/attendance_state.dart';
import 'package:fingerprint_attendance/views/connected_view.dart';
import 'package:fingerprint_attendance/views/connecting_view.dart';
import 'package:fingerprint_attendance/views/disconnected_view.dart';
import 'package:fingerprint_attendance/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fingerprint Attendance Tracker'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: context.read<AttendanceCubit>().disconnect,
          ),
        ],
      ),
      body: BlocConsumer<AttendanceCubit, AttendanceState>(
        listener: (context, state) {
          if (state is! AttendanceStateConnected ||
              (state.message?.isEmpty ?? true)) {
            return;
          }

          final cubit = context.read<AttendanceCubit>();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message ?? ''),
              duration: const Duration(seconds: 2),
            ),
          );

          Future.delayed(const Duration(seconds: 2), cubit.clearMessage);
        },
        builder: (_, state) => switch (state) {
          AttendanceStateDisconnected() => DisconnectedView(state: state),
          AttendanceStateConnecting() => const ConnectingView(),
          AttendanceStateConnected() => ConnectedView(state: state),
          AttendanceStateError() => ErrorView(state: state),
        },
      ),
    );
  }
}
