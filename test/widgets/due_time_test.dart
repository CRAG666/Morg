import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morg/document_screen.dart';

import '../helpers.dart';

Future<void> chooseDueDate(
  WidgetTester tester, {
  required bool withTime,
}) async {
  await pumpApp(
    tester,
    DocumentScreen.memory('- ( ) Call the bank\n', name: 'demo'),
  );
  final status = find.byWidgetPredicate(
    (widget) =>
        widget is GestureDetector &&
        widget.onLongPressStart != null &&
        widget.onTap != null,
  );
  await tester.longPress(status.first);
  await settle(tester);
  await tester.tap(find.text('Due date…'));
  await settle(tester);
  await tester.tap(find.text('OK'));
  await settle(tester);
  expect(find.byType(TimePickerDialog), findsOneWidget);
  await tester.tap(find.text(withTime ? 'OK' : 'Cancel'));
  await settle(tester);
}

void main() {
  testWidgets('the due date menu asks for an optional time', (tester) async {
    await chooseDueDate(tester, withTime: true);
    expect(
      find.textContaining(
        RegExp(r'\|< \w{3}, \d+ \w{3} \d{4} \d{2}:\d{2}\)'),
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the time keeps only the date', (tester) async {
    await chooseDueDate(tester, withTime: false);
    expect(
      find.textContaining(
        RegExp(r'\|< \w{3}, \d+ \w{3} \d{4}\)'),
        findRichText: true,
      ),
      findsOneWidget,
    );
  });
}
