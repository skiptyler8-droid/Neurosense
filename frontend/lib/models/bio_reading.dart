class BioReading {
  final String patientId;
  final double eda;
  final double hr;
  final int state;
  final String insight;
  final DateTime timestamp;

  BioReading({
    required this.patientId,
    required this.eda,
    required this.hr,
    required this.state,
    required this.insight,
    required this.timestamp,
  });

  factory BioReading.fromJson(Map<String, dynamic> j) => BioReading(
        patientId: j['patient_id'] as String,
        eda: (j['eda'] as num).toDouble(),
        hr: (j['hr'] as num).toDouble(),
        state: j['state'] as int,
        insight: j['insight'] as String? ?? '',
        timestamp: DateTime.now(),
      );

  static const stateLabels = ['Calm', 'Moderate Arousal', 'High Stress'];
  String get stateLabel => state < stateLabels.length ? stateLabels[state] : 'Unknown';
}
