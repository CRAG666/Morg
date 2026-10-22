import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morg/l10n/app_localizations.dart';
import 'package:morg/settings.dart';

const demoNote = '''@document.meta
title: Demo
@end

* (-) Launch plan
** (x) Write the announcement
** ( |< Fri, 30 Oct 2026) Record the demo
** (!) Fix the release workflow
* Groceries
  - ( ) Mangoes
  - (-) Dark chocolate
  -- ( ) 70% cacao
  -- (x) Sea salt
  - ( ) Carrots
* Notes
  A paragraph with a {* Launch plan} link, *bold*, /italic/ and `code`.
  ~ first
  ~ second
  > a quote
  @code dart
  void main() => print('hi');
  @end
''';

Future<Directory> temporaryFolder() =>
    Directory.systemTemp.createTemp('morg_test');

void mockSupportDirectory(String path) =>
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => path,
        );

Future<void> loadFonts() async {
  for (final (family, files) in [
    (
      'JetBrainsMono',
      [
        'JetBrainsMono-Regular',
        'JetBrainsMono-Bold',
        'JetBrainsMono-Italic',
        'JetBrainsMono-BoldItalic',
      ],
    ),
    ('SymbolsNerdFontMono', ['SymbolsNerdFontMono-Regular']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load('assets/fonts/$file.ttf'));
    }
    await loader.load();
  }
}

Future<SettingsController> pumpApp(
  WidgetTester tester,
  Widget home, {
  bool realFonts = false,
}) async {
  tester.view.physicalSize = const Size(824, 1830);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  if (realFonts) await tester.runAsync(loadFonts);
  final store = SettingsStore(directory: null, bundle: rootBundle);
  final controller = SettingsController(
    store,
    (await tester.runAsync(store.load))!,
  );
  await tester.pumpWidget(
    MorgSettingsScope(
      controller: controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFFE8A0BF),
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: const ['SymbolsNerdFontMono'],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: home,
      ),
    ),
  );
  await settle(tester);
  return controller;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}
