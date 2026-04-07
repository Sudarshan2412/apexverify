import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'services/comparison_service.dart';
import 'models/match_snapshot.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final logFile = File('C:/Users/Lenovo/apexverify_test_log.txt');
  await logFile.writeAsString('APP STARTED\n');

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await logFile.writeAsString('FIREBASE OK\n', mode: FileMode.append);
  } catch (e) {
    await logFile.writeAsString('FIREBASE ERROR: $e\n', mode: FileMode.append);
  }

  final firestoreService = FirestoreService();
  final comparisonService = ComparisonService(firestoreService);

  comparisonService.alertStream.listen((alert) {
    if (alert == null) {
      logFile.writeAsStringSync('CLEAN FRAME\n', mode: FileMode.append);
    } else {
      logFile.writeAsStringSync(
        'VIOLATION: ${alert.fieldMismatch} | Expected: ${alert.expected} | Actual: ${alert.actual}\n',
        mode: FileMode.append,
      );
    }
  });

  await comparisonService.compare(MatchSnapshot(
    homeTeam: 'Arsenal',
    awayTeam: 'Chelsea',
    score: '3 - 1',
    clock: "67'",
    hasOverlay: false,
  ));

  await comparisonService.compare(MatchSnapshot(
    homeTeam: 'Arsenal',
    awayTeam: 'Chelsea',
    score: '2 - 1',
    clock: "67'",
    hasOverlay: false,
  ));

  await comparisonService.compare(MatchSnapshot(
    homeTeam: 'Arsenal',
    awayTeam: 'Chelsea',
    score: '2 - 1',
    clock: "67'",
    hasOverlay: true,
  ));

  await logFile.writeAsString('TESTS DONE\n', mode: FileMode.append);

  runApp(const ApexVerifyApp());
}

class ApexVerifyApp extends StatelessWidget {
  const ApexVerifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('ApexVerify Running')),
      ),
    );
  }
}