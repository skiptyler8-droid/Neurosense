import 'package:flutter/material.dart';
import 'screens/monitor_screen.dart';

void main() {
  runApp(const NeuroSenseApp());
}

class NeuroSenseApp extends StatelessWidget {
  const NeuroSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5CC),
          secondary: Color(0xFF00E5CC),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        cardColor: const Color(0xFF141928),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00E5CC),
            foregroundColor: Colors.black,
          ),
        ),
      ),
      home: const ConnectScreen(),
    );
  }
}

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _idController = TextEditingController(text: 'P001');

  void _connect() {
    final id = _idController.text.trim();
    if (id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MonitorScreen(patientId: id)),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'NeuroSense',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: Color(0xFF00E5CC),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Real-time biofeedback monitoring',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'Patient ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _connect(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _connect,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Connect', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
