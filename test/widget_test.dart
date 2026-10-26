
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_quest/main.dart';

void main() {
  testWidgets('FocusQuest shows Focus and History navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FocusQuestApp());

    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Focus Session'), findsOneWidget);
  });
}
