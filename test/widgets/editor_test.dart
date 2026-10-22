import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morg/document_screen.dart';

import '../helpers.dart';

final headings = [for (var i = 1; i <= 12; i++) '** Heading number $i']
    .join('\n');

Future<Finder> openEditor(WidgetTester tester, String text) async {
  await pumpApp(
    tester,
    DocumentScreen.memory('* Top\n  - item\n$headings\n', name: 'demo'),
  );
  await tester.tap(find.textContaining('item', findRichText: true).first);
  await tester.pump(const Duration(milliseconds: 300));
  final field = find.byType(TextField);
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 300));
  return field;
}

TextEditingController controllerOf(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!;

void main() {
  testWidgets('dragging the cursor handle moves the cursor without closing', (
    tester,
  ) async {
    final field = await openEditor(tester, '- item text');
    await tester.tapAt(tester.getTopLeft(field) + const Offset(40, 10));
    await tester.pump(const Duration(milliseconds: 500));
    final handle = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_SelectionHandleOverlay',
      ),
      matching: find.byType(RawGestureDetector),
    );
    final before = controllerOf(tester, field).selection.baseOffset;
    final gesture = await tester.startGesture(tester.getCenter(handle.first));
    for (var step = 0; step < 10; step++) {
      await gesture.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(field, findsOneWidget);
    expect(
      controllerOf(tester, field).selection.baseOffset,
      greaterThan(before),
    );
  });

  testWidgets('link suggestions scroll sideways and insert the link', (
    tester,
  ) async {
    final field = await openEditor(tester, '- item {*');
    final list = find
        .ancestor(
          of: find.byType(ActionChip).first,
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(list).position;
    await tester.dragFrom(
      tester.getTopRight(list) + const Offset(-25, 20),
      const Offset(-150, 0),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(position.pixels, greaterThan(0));
    expect(field, findsOneWidget);
    final visible = tester.getRect(list);
    final chip = find
        .byType(ActionChip)
        .evaluate()
        .firstWhere(
          (element) =>
              visible.contains(tester.getCenter(find.byWidget(element.widget))),
        );
    await tester.tap(find.byWidget(chip.widget));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      controllerOf(tester, field).text,
      matches(RegExp(r'^- item \{\*+ [^}]+\}$')),
    );
  });

  testWidgets('tapping outside closes the editor and saves', (tester) async {
    final field = await openEditor(tester, '- item edited');
    await tester.tapAt(const Offset(200, 850));
    await settle(tester);
    expect(field, findsNothing);
    expect(find.textContaining('edited', findRichText: true), findsOneWidget);
  });
}
