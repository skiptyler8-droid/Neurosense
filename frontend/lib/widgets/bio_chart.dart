import 'package:flutter/material.dart';

class BioChart extends StatelessWidget {
  final List<double> values;
  final Color color;

  const BioChart({super.key, required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Center(
        child: Text(
          'Awaiting data...',
          style: TextStyle(color: Colors.white24, fontSize: 12),
        ),
      );
    }
    return CustomPaint(
      painter: _LinePainter(values: values, color: color),
      size: Size.infinite,
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _LinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min;
    final norm = range < 1e-9 ? 1.0 : range;
    final pad = size.height * 0.08;

    double xOf(int i) => i / (values.length - 1) * size.width;
    double yOf(double v) =>
        size.height - pad - ((v - min) / norm) * (size.height - pad * 2);

    final path = Path()..moveTo(xOf(0), yOf(values[0]));
    for (int i = 1; i < values.length; i++) {
      path.lineTo(xOf(i), yOf(values[i]));
    }

    final fillPath = Path()
      ..moveTo(xOf(0), size.height)
      ..lineTo(xOf(0), yOf(values[0]));
    for (int i = 1; i < values.length; i++) {
      fillPath.lineTo(xOf(i), yOf(values[i]));
    }
    fillPath
      ..lineTo(xOf(values.length - 1), size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withAlpha(76), color.withAlpha(0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values;
}
