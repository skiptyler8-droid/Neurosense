import 'package:flutter_test/flutter_test.dart';

import 'package:neurosense/main.dart';

void main() {
  testWidgets('NeuroSense app renders connect screen', (WidgetTester tester) async {
    await tester.pumpWidget(const NeuroSenseApp());

    expect(find.text('NeuroSense'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}
