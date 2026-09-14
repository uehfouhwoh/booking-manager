import 'package:booking_system/features/info/info_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Info screen shows the SDG concept summary', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: InfoScreen()));

    expect(find.text('FlowSlot Campus'), findsOneWidget);
    expect(find.text('SDG Alignment'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('Timing Calculation'), findsOneWidget);
  });
}
