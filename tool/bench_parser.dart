import 'dart:io';

import 'package:morg/norg/parser.dart';

const _runs = 20;

void main(List<String> roots) {
  final sources = [
    for (final root in roots.isEmpty ? ['assets'] : roots)
      for (final entity in Directory(root).listSync(recursive: true))
        if (entity.path.endsWith('.norg')) File(entity.path).readAsStringSync(),
  ];
  final corpus = sources.join('\n');
  for (var warmup = 0; warmup < 3; warmup++) {
    parseNorg(corpus);
  }
  final watch = Stopwatch()..start();
  for (var run = 0; run < _runs; run++) {
    parseNorg(corpus);
  }
  final milliseconds = watch.elapsedMicroseconds / _runs / 1000;
  final mebibytesPerSecond = corpus.length / 1048576 / milliseconds * 1000;
  stdout.writeln(
    '${sources.length} files, ${corpus.length ~/ 1024} KiB: '
    '${milliseconds.toStringAsFixed(2)} ms per parse '
    '(${mebibytesPerSecond.toStringAsFixed(1)} MiB/s)',
  );
}
