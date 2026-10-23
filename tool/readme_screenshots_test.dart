import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morg/main.dart';
import 'package:morg/norg/dates.dart';
import 'package:morg/settings.dart';

import '../test/helpers.dart';

DateTime _inDays(int days) => DateTime.now().add(Duration(days: days));

String _index() {
  final today = DateTime.now();
  final evening = DateTime(today.year, today.month, today.day, 18);
  return '''@document.meta
title: Index
description: Everything starts here
authors: morg
categories: [home]
created: 2026-10-01
@end

* (-) This week
  - (x) Draft the {:projects/morg:}[release notes]
  - ( |< ${norgDate(evening, withTime: true)}) Call the bank
  - (!|< ${norgDate(_inDays(1))}|# A) Renew the passport
  - ( |> ${norgDate(_inDays(3))}) Plan the trip to {https://en.wikipedia.org/wiki/Lisbon}[Lisbon]
  - (=) Waiting for the delivery
  - (+ Monday) Water the plants
* Reading list
  - (-) /The Pragmatic Programmer/
  -- (x) Chapter 1
  -- ( ) Chapter 2
  - (?) /Designing Data-Intensive Applications/
* Ideas
  Notes are *plain text* in /Norg/, with math like \$e^{i\\pi}+1=0\$ and `inline code`.
  > Simplicity is prerequisite for reliability.
  ~ Capture
  ~ Organize
  ~ Review
  @code dart
  final notes = await workspace.list();
  @end
''';
}

String _roadmap() =>
    '''@document.meta
title: Morg roadmap
@end

* Roadmap
** (x) Norg parser
** (x) Agenda and task list
** ( |< ${norgDate(_inDays(6))}) Share text into Morg
   Demo on {@ ${norgDate(_inDays(2))}} with the team.
''';

String _journal(DateTime day) =>
    '''@document.meta
title: ${norgDate(day)}
@end

* Journal
  Reviewed the {:../../../projects/morg:}[roadmap].
''';

Future<Directory> _workspace(Map<String, String> extraNotes) async {
  final root = Directory('${Directory.systemTemp.path}/Notes');
  if (await root.exists()) throw StateError('${root.path} already exists');
  final today = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  for (final (path, content) in [
    ('index.norg', _index()),
    ('projects/morg.norg', _roadmap()),
    ('recipes.norg', '* Recipes\n  - Mango lassi\n  - Shakshuka\n'),
    (
      'journal/${today.year}/${two(today.month)}/${two(today.day)}.norg',
      _journal(today),
    ),
    ...extraNotes.entries.map((note) => (note.key, note.value)),
  ]) {
    final file = File('${root.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }
  return root;
}

const _regular = 'assets/fonts/JetBrainsMono-Regular.ttf';
const _withFallback = 'build/screenshot-fonts/JetBrainsMono-Regular.ttf';

Future<ByteData> _readFont(String path) =>
    File(path).readAsBytes().then(ByteData.sublistView);

Future<void> _mergeFallbackGlyphs() async {
  await Directory(_withFallback).parent.create(recursive: true);
  final merge = await Process.run('uvx', [
    '--from',
    'fonttools',
    'pyftmerge',
    _regular,
    '/usr/share/fonts/Adwaita/AdwaitaMono-Regular.ttf',
    '--output-file=$_withFallback',
  ]);
  if (merge.exitCode != 0) throw ProcessException('uvx', [], merge.stderr);
}

Future<void> _loadFonts() async {
  await loadFonts(
    load: (asset) =>
        asset == _regular ? _readFont(_withFallback) : rootBundle.load(asset),
  );
  await (FontLoader(
    'Noto Color Emoji',
  )..addFont(_readFont('/usr/share/fonts/noto/NotoColorEmoji.ttf'))).load();
}

Future<SettingsController> _pumpMorg(
  WidgetTester tester, {
  String themeMode = 'dark',
  Size size = const Size(412, 915),
  double pixelRatio = 2,
  Map<String, String> extraNotes = const {},
}) async {
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
  await tester.runAsync(_loadFonts);
  final root = (await tester.runAsync(() => _workspace(extraNotes)))!;
  final support = (await tester.runAsync(temporaryFolder))!;
  addTearDown(() {
    root.deleteSync(recursive: true);
    support.deleteSync(recursive: true);
  });
  mockSupportDirectory(support.path);
  final store = SettingsStore(directory: null, bundle: rootBundle);
  final controller = SettingsController(
    store,
    (await tester.runAsync(store.load))!,
  );
  await tester.runAsync(() async {
    await controller.setValue(['theme_mode'], themeMode);
    await controller.setWorkspace('notes', root.path);
    await controller.setValue([
      'load',
      'core.dirman',
      'config',
      'default_workspace',
    ], 'notes');
  });
  await tester.pumpWidget(
    MorgSettingsScope(controller: controller, child: const MorgApp()),
  );
  await settle(tester);
  return controller;
}

Future<void> _shot(
  WidgetTester tester,
  String name, {
  String directory = 'docs/screenshots',
}) async {
  await settle(tester);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../$directory/$name.png'),
  );
}

Future<void> _back(WidgetTester tester) async {
  await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
  await settle(tester);
}

Finder _text(String text) =>
    find.textContaining(text, findRichText: true).first;

void main() {
  setUpAll(_mergeFallbackGlyphs);

  testWidgets('workspace, note, menus, editing and search', (tester) async {
    await _pumpMorg(tester);
    await _shot(tester, 'home');

    await tester.tap(find.text('notes'));
    await _shot(tester, 'document');

    await tester.tap(find.byIcon(Icons.more_vert));
    await _shot(tester, 'note-menu');
    await tester.tap(find.text('Browse files'));
    await _shot(tester, 'browser');
    await _back(tester);

    await tester.tap(find.byIcon(Icons.toc));
    await _shot(tester, 'outline');
    await _back(tester);

    final statuses = find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector &&
          widget.onLongPressStart != null &&
          widget.onTap != null,
    );
    await tester.longPress(statuses.at(2));
    await _shot(tester, 'task-menu');
    await _back(tester);

    await tester.longPressAt(
      tester.getTopLeft(_text('Waiting for the delivery')) -
          const Offset(30, -8),
    );
    await _shot(tester, 'element-menu');
    await _back(tester);

    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'roadmap');
    await _shot(tester, 'search');
    await tester.tap(find.byIcon(Icons.clear));
    await tester.tap(find.text('Agenda'));
    await _shot(tester, 'agenda');
    await tester.tap(find.text('Tasks'));
    await _shot(tester, 'tasks');
    await _back(tester);

    await tester.tap(_text('Notes are'));
    await settle(tester);
    await tester.enterText(
      find.byType(TextField),
      'Notes are *plain text* in /Norg/. See the {:pro',
    );
    await _shot(tester, 'editing');
  });

  testWidgets('Neorg guide in the light theme', (tester) async {
    await _pumpMorg(tester, themeMode: 'light');
    await tester.tap(find.text('Quick Neorg guide'));
    await _shot(tester, 'guide-light');
  });

  testWidgets('the Norg guide next to Neovim', (tester) async {
    await _pumpMorg(
      tester,
      pixelRatio: 1,
      extraNotes: {
        'guide.norg': File('tool/readme_guide.norg').readAsStringSync(),
      },
    );
    await tester.tap(find.text('notes'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text('Browse files'));
    await settle(tester);
    await tester.tap(find.text('guide'));
    await _shot(tester, 'guide-morg', directory: 'build/readme');
  });
}
