import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morg/main.dart';

import '../helpers.dart';

const _drive = 'content://com.google.android.apps.docs.storage/tree/notes';

Future<List<String>> removeDrive(
  WidgetTester tester, {
  required bool granted,
  required Map<String, String> workspaces,
}) async {
  final released = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('saf_util'),
    (call) async => switch (call.method) {
      'hasPersistedPermission' => granted,
      'releasePersistedPermission' =>
        granted
            ? released.add(call.arguments['uri'] as String)
            : throw PlatformException(
                code: 'PluginError',
                message: 'No persistable permission grants found',
              ),
      _ => null,
    },
  );
  final controller = await pumpApp(tester, const HomeScreen());
  await tester.runAsync(() async {
    for (final MapEntry(:key, :value) in workspaces.entries) {
      await controller.setWorkspace(key, value);
    }
  });
  await settle(tester);
  await tester.longPress(find.text('Drive'));
  await settle(tester);
  await tester.tap(find.text('Remove'));
  await settle(tester);
  await tester.tap(find.text('Remove').last);
  await settle(tester);
  return released;
}

void main() {
  testWidgets('a Drive workspace whose permission was lost is removed', (
    tester,
  ) async {
    await removeDrive(tester, granted: false, workspaces: {'Drive': _drive});
    expect(find.text('Drive'), findsNothing);
  });

  testWidgets('removing a Drive workspace releases its permission', (
    tester,
  ) async {
    final released = await removeDrive(
      tester,
      granted: true,
      workspaces: {'Drive': _drive},
    );
    expect(find.text('Drive'), findsNothing);
    expect(released, [_drive]);
  });

  testWidgets('a folder shared with another workspace keeps its permission', (
    tester,
  ) async {
    final released = await removeDrive(
      tester,
      granted: true,
      workspaces: {'Drive': _drive, 'Drive copy': _drive},
    );
    expect(find.text('Drive'), findsNothing);
    expect(find.text('Drive copy'), findsOneWidget);
    expect(released, isEmpty);
  });
}
