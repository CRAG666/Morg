import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morg/settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers.dart';

void main() {
  testWidgets('settings show the version and the developer', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Morg',
      packageName: 'dev.morg.morg',
      version: '1.2.3',
      buildNumber: '24',
      buildSignature: '',
    );
    await pumpApp(tester, const SettingsScreen());
    await tester.scrollUntilVisible(
      find.text('About Morg'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    expect(find.text('Version 1.2.3 (24)'), findsOneWidget);
    await tester.tap(find.text('About Morg'));
    await settle(tester);
    expect(find.text('Developed by Crag'), findsOneWidget);
    expect(find.text('Source code'), findsOneWidget);
    expect(find.text('Report a problem'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);
  });
}
