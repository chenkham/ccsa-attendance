import 'package:flutter_test/flutter_test.dart';
import 'package:ccsa_smart_attendance/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CCSASmartAttendanceApp());
    expect(find.byType(CCSASmartAttendanceApp), findsOneWidget);
  });
}
