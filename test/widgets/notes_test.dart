import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morg/workspace/store.dart';
import 'package:morg/workspace/workspace.dart';
import 'package:morg/workspace_screen.dart';

import '../helpers.dart';

void main() {
  testWidgets('deleting a note can be undone with the same content', (
    tester,
  ) async {
    final root = (await tester.runAsync(temporaryFolder))!;
    addTearDown(() => root.deleteSync(recursive: true));
    const content = '* Keep\n  - exact text ✓\n';
    File('${root.path}/keep.norg').writeAsStringSync(content);
    await pumpApp(
      tester,
      WorkspaceScreen(workspace: Workspace('demo', LocalStore(root))),
    );
    await tester.longPress(find.text('keep'));
    await settle(tester);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    expect(File('${root.path}/keep.norg').existsSync(), isFalse);
    expect(find.text('keep'), findsNothing);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(File('${root.path}/keep.norg').readAsStringSync(), content);
    expect(find.text('keep'), findsOneWidget);
  });
}
