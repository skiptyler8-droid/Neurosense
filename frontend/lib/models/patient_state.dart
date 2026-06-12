import 'package:flutter/foundation.dart';
import 'bio_reading.dart';

class PatientState extends ChangeNotifier {
  final String patientId;
  BioReading? latest;
  final List<BioReading> history = [];
  bool alert = false;
  static const int maxHistory = 120;

  PatientState(this.patientId);

  void addReading(BioReading r) {
    latest = r;
    history.add(r);
    if (history.length > maxHistory) history.removeAt(0);
    notifyListeners();
  }

  void triggerAlert() {
    alert = true;
    notifyListeners();
  }

  void clearAlert() {
    alert = false;
    notifyListeners();
  }
}
