import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morg/find_screen.dart';
import 'package:morg/norg/dates.dart';
import 'package:morg/workspace/store.dart';
import 'package:morg/workspace/workspace.dart';

import '../helpers.dart';

void main() {
  testWidgets('search, agenda and tasks come from the workspace', (
    tester,
  ) async {
    final tomorrow = norgDate(DateTime.now().add(const Duration(days: 1)));
    final notes = MemoryStore('find', {
      'a.norg': '* (-) Launch plan\n** ( |< $tomorrow) Record the demo\n',
      'sub/b.norg': '* Shopping\n  - (!) Mangoes\n\n  launch party\n',
    });
    await pumpApp(
      tester,
      FindScreen(
        workspace: Workspace('find', notes),
        initialTab: FindTab.agenda,
      ),
    );
    expect(tester.widgetList<Tab>(find.byType(Tab)).map((tab) => tab.text), [
      'Search',
      'Agenda',
      'Tasks',
    ]);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Record the demo'), findsOneWidget);
    await tester.tap(find.text('Tasks'));
    await settle(tester);
    expect(find.text('Mangoes'), findsOneWidget);
    await tester.tap(find.text('Search'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'party');
    await settle(tester);
    expect(find.text('launch party'), findsOneWidget);
  });
}
