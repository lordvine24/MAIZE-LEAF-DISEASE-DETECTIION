import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    debugPrint('[Startup] Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(FirebaseStartupErrorApp(error: error.toString()));
    return;
  }

  if (!kIsWeb) {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error, stackTrace) {
      debugPrint('[Startup] Firebase session clear failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    try {
      await GoogleSignIn().signOut();
    } catch (error, stackTrace) {
      debugPrint('[Startup] Google session clear failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  runApp(const ProviderScope(child: ChloroScanApp()));
}

class FirebaseStartupErrorApp extends StatelessWidget {
  final String error;

  const FirebaseStartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Firebase could not start',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('Startup error:'),
                  const SizedBox(height: 8),
                  SelectableText(error),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
