import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_portal/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const DoctorPortalApp());
    expect(find.text('TemanU Doctor Portal'), findsNothing); // Basic sanity check
  });
}
