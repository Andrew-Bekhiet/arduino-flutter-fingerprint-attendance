import 'package:fingerprint_attendance/cubit/attendance_cubit.dart';
import 'package:fingerprint_attendance/repositories/arduino_repository.dart';
import 'package:fingerprint_attendance/repositories/storage_repository.dart';
import 'package:fingerprint_attendance/views/attendance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive storage
  final storageRepo = StorageRepository();
  await storageRepo.init();

  runApp(MainApp(storageRepository: storageRepo));
}

class MainApp extends StatelessWidget {
  final StorageRepository storageRepository;

  const MainApp({required this.storageRepository, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AttendanceCubit(ArduinoRepository(), storageRepository),
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
