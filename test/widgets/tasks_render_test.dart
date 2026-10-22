import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morg/document_screen.dart';
import 'package:morg/find_screen.dart';
import 'package:morg/norg/dates.dart';
import 'package:morg/workspace/store.dart';
import 'package:morg/workspace/workspace.dart';

import '../helpers.dart';

void main() {
  testWidgets('recurrences and timestamps are shown in the note', (
    tester,
  ) async {
    await pumpApp(
      tester,
      DocumentScreen.memory(
        "- (+ 5th Jan) birthday\n\nFrank's party is on {@ 5th May}.\n",
        name: 'demo',
      ),
    );
    expect(find.textContaining('5th Jan', findRichText: true), findsWidgets);
    final party = find.textContaining('5th May', findRichText: true);
    expect(party, findsOneWidget);
    final span = (tester.widget<RichText>(party).text as TextSpan);
    final recognizers = <GestureRecognizer>[];
    span.visitChildren((child) {
      if (child is TextSpan && child.recognizer != null) {
        recognizers.add(child.recognizer!);
      }
      return true;
    });
    expect(recognizers, isEmpty);
  });

  testWidgets('the agenda lists recurrences, dated items and timestamps', (
    tester,
  ) async {
    String day(int offset) =>
        norgDate(DateTime.now().add(Duration(days: offset)));
    final notes = MemoryStore('agenda', {
      'a.norg':
          '- (< ${day(2)}) dated without status\n'
          '- ( |< ${day(1)} 18:00) timed task\n'
          '- (# A) only a priority\n\n'
          'Party on {@ ${day(3)}}.\n',
    });
    await pumpApp(
      tester,
      FindScreen(
        workspace: Workspace('agenda', notes),
        initialTab: FindTab.agenda,
      ),
    );
    expect(find.text('dated without status'), findsOneWidget);
    expect(find.text('only a priority'), findsNothing);
    expect(find.textContaining('Party on'), findsOneWidget);
    expect(find.byIcon(Icons.event_outlined), findsNWidgets(2));
    expect(find.textContaining('6:00 PM'), findsOneWidget);
  });
}
