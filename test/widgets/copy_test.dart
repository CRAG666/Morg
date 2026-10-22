import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morg/document_screen.dart';

import '../helpers.dart';

void main() {
  testWidgets('copying puts one element per line in Norg notation', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await pumpApp(
      tester,
      DocumentScreen.memory(
        '* Top\n  - (x) done task\n  ~ first\n** Sub\n   text\n',
        name: 'demo',
      ),
    );
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll(SelectionChangedCause.toolbar);
    await tester.pump();
    Actions.invoke(
      tester.element(find.byType(Scrollable).first),
      CopySelectionTextIntent.copy,
    );
    await tester.pump();
    expect(copied, 'Top\n(x) done task\n1. first\nSub\ntext\n');
  });
}
