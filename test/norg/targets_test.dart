import 'package:flutter_test/flutter_test.dart';
import 'package:morg/norg/ast.dart';
import 'package:morg/norg/parser.dart';
import 'package:morg/norg/targets.dart';

void main() {
  final targets = DocumentTargets(
    parseNorg(
      '* Top\n** Inner Title\n\$ Term\nmeaning\n^ Note\nbody\n#name named\n> quote\n'
      'A [site]{https://x.org} link.',
    ),
  );

  test('headings resolve by level, ignoring case and spaces', () {
    expect(targets.lineOf('** innertitle'), 1);
    expect(targets.lineOf('* Inner Title'), isNull);
  });

  test('definitions, footnotes and generic names resolve', () {
    expect(targets.lineOf(r'$ Term'), 2);
    expect(targets.lineOf('^ Note'), 4);
    expect(targets.lineOf('# named'), 7);
  });

  test('anchors point where their declaration links', () {
    expect(targets.anchorTarget(const [TextInline('site')]), 'https://x.org');
  });

  test('locations list linkable places in order', () {
    expect(targets.locations, ['* Top', '** Inner Title', r'$ Term', '^ Note']);
  });
}
