import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/bio_reading.dart';
import '../models/patient_state.dart';

// Use 10.0.2.2 when running on Android emulator, localhost for web/desktop.
const String _kHost =
    String.fromEnvironment('WS_HOST', defaultValue: 'localhost:8000');

class BioService {
  final Map<String, WebSocketChannel> _channels = {};
  final Map<String, StreamSubscription> _subs = {};

  void connect(PatientState patient) {
    final uri = Uri.parse('ws://$_kHost/ws/monitor/${patient.patientId}');
    final channel = WebSocketChannel.connect(uri);
    _channels[patient.patientId] = channel;

    _subs[patient.patientId] = channel.stream.listen(
      (raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        final type = msg['type'] as String?;
        if (type == 'update') {
          patient.addReading(BioReading.fromJson(msg));
        } else if (type == 'alert') {
          patient.triggerAlert();
        }
      },
      onError: (_) => _reconnect(patient),
      onDone: () => _reconnect(patient),
    );
  }

  void _reconnect(PatientState patient) {
    Future.delayed(const Duration(seconds: 3), () => connect(patient));
  }

  void disconnect(String patientId) {
    _subs[patientId]?.cancel();
    _channels[patientId]?.sink.close();
    _subs.remove(patientId);
    _channels.remove(patientId);
  }

  void disposeAll() {
    for (final id in List.of(_channels.keys)) {
      disconnect(id);
    }
  }
}
