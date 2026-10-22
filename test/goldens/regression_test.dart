@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morg/document_screen.dart';
import 'package:morg/find_screen.dart';
import 'package:morg/main.dart';
import 'package:morg/workspace/store.dart';
import 'package:morg/workspace/workspace.dart';

import '../helpers.dart';

Future<void> matchesScreen(String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('$name.png'));

void main() {
  testWidgets('demo note', (tester) async {
    await pumpApp(
      tester,
      DocumentScreen.memory(demoNote, name: 'demo'),
      realFonts: true,
    );
    await matchesScreen('demo');
  });

  testWidgets('element menu', (tester) async {
    await pumpApp(
      tester,
      DocumentScreen.memory(demoNote, name: 'demo'),
      realFonts: true,
    );
    await tester.longPressAt(
      tester.getTopLeft(
            find.textContaining('Mangoes', findRichText: true).first,
          ) -
          const Offset(30, -8),
    );
    await settle(tester);
    await matchesScreen('element-menu');
  });

  testWidgets('task menu, then done, undo and redo', (tester) async {
    await pumpApp(
      tester,
      DocumentScreen.memory(demoNote, name: 'demo'),
      realFonts: true,
    );
    final status = find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector &&
          widget.onLongPressStart != null &&
          widget.onTap != null,
    );
    await tester.longPress(status.first);
    await settle(tester);
    await matchesScreen('task-menu');
    await tester.tap(find.text('Done').last);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.undo));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.redo));
    await settle(tester);
    await matchesScreen('after-undo-redo');
  });

  testWidgets('Neorg guide', (tester) async {
    final guide = File('assets/docs/neorg.norg').readAsStringSync();
    await pumpApp(
      tester,
      DocumentScreen.memory(guide, name: 'neorg'),
      realFonts: true,
    );
    await matchesScreen('guide-0');
    for (var page = 1; page <= 3; page++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
      await settle(tester);
      await matchesScreen('guide-$page');
    }
  });

  testWidgets('task list', (tester) async {
    final notes = MemoryStore('golden', {
      'a.norg': demoNote,
      'sub/b.norg': '* (!) Urgent thing\n  - (?) unsure\n',
    });
    await pumpApp(
      tester,
      FindScreen(
        workspace: Workspace('golden', notes),
        initialTab: FindTab.tasks,
      ),
      realFonts: true,
    );
    await matchesScreen('find-tasks');
  });

  testWidgets('home', (tester) async {
    await pumpApp(tester, const HomeScreen(), realFonts: true);
    await matchesScreen('home');
  });
}
