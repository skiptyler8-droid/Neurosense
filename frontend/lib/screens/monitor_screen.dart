import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bio_reading.dart';
import '../models/patient_state.dart';
import '../services/bio_service.dart';
import '../widgets/bio_chart.dart';

class MonitorScreen extends StatefulWidget {
  final String patientId;
  const MonitorScreen({super.key, required this.patientId});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  late final PatientState _patient;
  late final BioService _bioService;

  @override
  void initState() {
    super.initState();
    _patient = PatientState(widget.patientId);
    _bioService = BioService();
    _bioService.connect(_patient);
  }

  @override
  void dispose() {
    _bioService.disconnect(widget.patientId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _patient,
      child: Consumer<PatientState>(
        builder: (context, patient, _) => Scaffold(
          appBar: AppBar(
            title: Text('Patient ${patient.patientId}'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              if (patient.alert)
                TextButton.icon(
                  onPressed: patient.clearAlert,
                  icon: const Icon(Icons.notifications_active,
                      color: Colors.redAccent),
                  label: const Text('Dismiss',
                      style: TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
          body: Column(
            children: [
              if (patient.alert) _AlertBanner(onDismiss: patient.clearAlert),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _MetricRow(reading: patient.latest),
                    const SizedBox(height: 12),
                    _StateCard(reading: patient.latest),
                    const SizedBox(height: 12),
                    _ChartCard(
                      title: 'EDA (µS)',
                      history: patient.history,
                      getValue: (r) => r.eda,
                      color: const Color(0xFF00E5CC),
                    ),
                    const SizedBox(height: 10),
                    _ChartCard(
                      title: 'HR (bpm)',
                      history: patient.history,
                      getValue: (r) => r.hr,
                      color: const Color(0xFFFF6B6B),
                    ),
                    const SizedBox(height: 12),
                    _InsightCard(reading: patient.latest),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Alert banner ──────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  const _AlertBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.redAccent.withAlpha(40),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Alert triggered for this patient',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Metric cards (EDA + HR) ───────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  final BioReading? reading;
  const _MetricRow({required this.reading});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'EDA',
            value: reading != null ? reading!.eda.toStringAsFixed(2) : '–',
            unit: 'µS',
            color: const Color(0xFF00E5CC),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'HR',
            value: reading != null ? reading!.hr.toStringAsFixed(0) : '–',
            unit: 'bpm',
            color: const Color(0xFFFF6B6B),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 11, letterSpacing: 1.8),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    unit,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white38),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── State chip ────────────────────────────────────────────────────────────────

class _StateCard extends StatelessWidget {
  final BioReading? reading;
  const _StateCard({required this.reading});

  static const _stateColors = [
    Color(0xFF4CAF50),
    Color(0xFFFFC107),
    Color(0xFFF44336),
  ];

  @override
  Widget build(BuildContext context) {
    final state = reading?.state ?? 0;
    final label = reading != null ? reading!.stateLabel : 'Awaiting data...';
    final color = state < _stateColors.length ? _stateColors[state] : Colors.grey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            const Text(
              'STATE',
              style: TextStyle(
                  color: Colors.white38, fontSize: 11, letterSpacing: 1.8),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withAlpha(38),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withAlpha(153)),
              ),
              child: Text(
                label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sparkline chart ───────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final List<BioReading> history;
  final double Function(BioReading) getValue;
  final Color color;

  const _ChartCard({
    required this.title,
    required this.history,
    required this.getValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                  color: color, fontSize: 11, letterSpacing: 1.8),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: BioChart(
                values: history.map(getValue).toList(),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── AI insight ────────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final BioReading? reading;
  const _InsightCard({required this.reading});

  @override
  Widget build(BuildContext context) {
    final insight = reading?.insight ?? '';
    if (insight.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI INSIGHT',
              style: TextStyle(
                  color: Colors.white38, fontSize: 11, letterSpacing: 1.8),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.psychology_outlined,
                    size: 18, color: Color(0xFF00E5CC)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "AI insights powered by Claude (cloud-processed)",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
