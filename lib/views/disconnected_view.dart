import 'package:fingerprint_attendance/cubit/attendance_cubit.dart';
import 'package:fingerprint_attendance/cubit/attendance_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DisconnectedView extends StatelessWidget {
  final AttendanceStateDisconnected state;

  const DisconnectedView({required this.state, super.key});

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
