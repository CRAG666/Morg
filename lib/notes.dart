import 'package:path/path.dart' as p;

import 'norg/edits.dart';
import 'settings.dart';
import 'workspace/store.dart';

String _two(int value) => value.toString().padLeft(2, '0');

String journalEntryPath(MorgConfig config, DateTime date) =>
    p.posix.join(config.journalFolder, switch (config.journalStrategy) {
      JournalStrategy.nested => p.posix.join(
        '${date.year}',
        _two(date.month),
        '${_two(date.day)}.norg',
      ),
      JournalStrategy.flat =>
        '${date.year}-${_two(date.month)}-${_two(date.day)}.norg',
    });

DateTime? journalDateOf(MorgConfig config, String path) {
  final folder = p.posix.normalize(config.journalFolder);
  if (!p.posix.isWithin(folder, path)) return null;
  final entry = p.posix.withoutExtension(p.posix.relative(path, from: folder));
  final match = switch (config.journalStrategy) {
    JournalStrategy.nested => RegExp(r'^(\d{4})/(\d{2})/(\d{2})$'),
    JournalStrategy.flat => RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'),
  }.firstMatch(entry);
  if (match == null) return null;
  return DateTime(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
  );
}

Future<NoteRef> journalEntry(
  NoteStore store,
  MorgConfig config,
  DateTime date,
) async {
  final ref = NoteRef(store, journalEntryPath(config, date));
  if (await store.exists(ref.path)) return ref;
  final template = p.posix.join(config.journalFolder, config.journalTemplate);
  final useTemplate = config.useJournalTemplate && await store.exists(template);
  await createNote(
    ref,
    author: config.author,
    contents: useTemplate ? await store.read(template) : null,
  );
  return ref;
}

Future<void> createNote(
  NoteRef ref, {
  required String author,
  String? contents,
}) => ref.store.write(
  ref.path,
  contents ??
      metadataTemplate(title: ref.name, author: author, now: DateTime.now()),
);
