// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get themeLight => 'Light theme';

  @override
  String get themeDark => 'Dark theme';

  @override
  String saveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get unsavedChangesTitle => 'Unsaved changes';

  @override
  String get discardChangesQuestion => 'Discard your changes?';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discard => 'Discard';

  @override
  String get save => 'Save';

  @override
  String themeImported(String name) {
    return 'Theme \"$name\" imported. Enable it with \"theme\": \"$name\".';
  }

  @override
  String get pickThemeFile => 'Exported theme (.json)';

  @override
  String get resetConfigTitle => 'Reset configuration';

  @override
  String get resetConfigBody =>
      'morg.json will be replaced with the default configuration.';

  @override
  String get cancel => 'Cancel';

  @override
  String get reset => 'Reset';

  @override
  String get settings => 'Settings';

  @override
  String get editConfig => 'Edit configuration';

  @override
  String get editConfigSubtitle =>
      'morg.json — same structure as neorg.setup()';

  @override
  String get importTheme => 'Import Neovim theme';

  @override
  String currentTheme(String name) {
    return 'Current theme: $name';
  }

  @override
  String get restoreDefaults => 'Restore default configuration';

  @override
  String couldNotOpen(String target) {
    return 'Could not open $target';
  }

  @override
  String couldNotOpenBecause(String target, String error) {
    return 'Could not open $target: $error';
  }

  @override
  String notFound(String location) {
    return 'Not found: “$location”';
  }

  @override
  String unsupportedLink(String target) {
    return 'Unsupported link: $target';
  }

  @override
  String get noteMissingTitle => 'This note does not exist';

  @override
  String createNoteQuestion(String path, String location) {
    return 'Create $path in $location?';
  }

  @override
  String get create => 'Create';

  @override
  String get edit => 'Edit';

  @override
  String couldNotRead(String error) {
    return 'Could not read: $error';
  }

  @override
  String couldNotReadAt(String location, String error) {
    return 'Could not read $location:\n$error';
  }

  @override
  String get newNote => 'New note';

  @override
  String get newNoteHint => 'name or folder/name';

  @override
  String get index => 'Index';

  @override
  String get journalToday => 'Today\'s journal';

  @override
  String get syncConflict => 'Syncthing conflict';

  @override
  String get workspaceName => 'Workspace name';

  @override
  String get workspaceNameHint => 'same as in Neovim, e.g. notes';

  @override
  String get add => 'Add';

  @override
  String removeWorkspace(String name) {
    return 'Remove “$name”';
  }

  @override
  String get removeWorkspaceBody =>
      'It is removed from morg.json. No files are deleted.';

  @override
  String get remove => 'Remove';

  @override
  String get fileAccess => 'File access';

  @override
  String get fileAccessBody =>
      'Needed for local workspaces; cloud folders work without it.';

  @override
  String get grant => 'Grant';

  @override
  String get workspaces => 'Workspaces';

  @override
  String get workspaceMissing => 'Not on this phone · tap to choose its folder';

  @override
  String get openFile => 'Open file…';

  @override
  String get pickNorgFile => 'Open a Norg file';

  @override
  String get alsoFromCloud => 'Also from the cloud';

  @override
  String get norgGuide => 'Neorg help page';

  @override
  String get importConfig => 'Import configuration';

  @override
  String get importConfigSubtitle =>
      'Replace morg.json with a file, e.g. from your synced notes';

  @override
  String get pickConfigFile => 'Configuration file (morg.json)';

  @override
  String get configImported => 'Configuration imported';

  @override
  String invalidFile(String error) {
    return 'Invalid file: $error';
  }

  @override
  String get themeSystem => 'System theme';

  @override
  String get addWorkspace => 'Add workspace';

  @override
  String get noWorkspaces =>
      'No workspaces yet. Tap “Add workspace” and choose the folder of your notes.';

  @override
  String get browseFiles => 'Browse files';

  @override
  String get changeFolder => 'Change folder';

  @override
  String get rename => 'Rename';

  @override
  String noIndexTitle(String file) {
    return 'No $file here';
  }

  @override
  String get noIndexBody =>
      'Create it, like Neorg\'s index, or browse the workspace files?';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeMode => 'Theme';

  @override
  String get colorscheme => 'Colorscheme';

  @override
  String get rendering => 'Rendering (core.concealer)';

  @override
  String get headingIcons => 'Heading icons (one per level)';

  @override
  String get listIcons => 'List icons';

  @override
  String get quoteIcons => 'Quote icons';

  @override
  String get hideCodeTags => 'Hide @code and @end lines';

  @override
  String get notesSection => 'Notes';

  @override
  String get author => 'Author (metagen)';

  @override
  String get indexFile => 'Index file';

  @override
  String get defaultWorkspace => 'Default workspace';

  @override
  String get none => 'None';

  @override
  String get journal => 'Journal';

  @override
  String get journalFolder => 'Journal folder';

  @override
  String get journalStrategy => 'Entry path';

  @override
  String get strategyNested => '2026/10/20.norg';

  @override
  String get strategyFlat => '2026-10-20.norg';

  @override
  String get journalTemplate => 'Template file';

  @override
  String get useTemplate => 'Use the template';

  @override
  String get advanced => 'Advanced';

  @override
  String get defaultSetting => 'Default';

  @override
  String get language => 'Language';

  @override
  String get systemLanguage => 'System';

  @override
  String get norgCheatsheet => 'Quick Neorg guide';

  @override
  String get todoUndone => 'Undone';

  @override
  String get todoDone => 'Done';

  @override
  String get todoNeedsInput => 'Needs further input';

  @override
  String get todoUrgent => 'Urgent';

  @override
  String get todoRecurring => 'Recurring';

  @override
  String get todoPending => 'Pending';

  @override
  String get todoOnHold => 'On hold';

  @override
  String get todoCancelled => 'Cancelled';

  @override
  String get agenda => 'Agenda';

  @override
  String get clear => 'Clear';

  @override
  String get delete => 'Delete';

  @override
  String get deleted => 'Deleted';

  @override
  String get promote => 'Promote';

  @override
  String get demote => 'Demote';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get toOrdered => 'Make it a numbered list';

  @override
  String get toUnordered => 'Make it a bulleted list';

  @override
  String get makeTask => 'Make it a task';

  @override
  String get focus => 'Focus';

  @override
  String get unfocus => 'Stop focusing';

  @override
  String focusedOn(String title) {
    return 'Focused on $title';
  }

  @override
  String get dueDate => 'Due date…';

  @override
  String get removeDueDate => 'Remove due date';

  @override
  String dueOn(String date) {
    return 'Due $date';
  }

  @override
  String startsOn(String date) {
    return 'Starts $date';
  }

  @override
  String happensOn(String date) {
    return 'On $date';
  }

  @override
  String priority(String priority) {
    return 'Priority $priority';
  }

  @override
  String get exportMarkdown => 'Export to Markdown';

  @override
  String get exported => 'Exported';

  @override
  String get journalOnDate => 'Journal for a date…';

  @override
  String get previousDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String get noDatedTasks =>
      'No tasks with dates yet. Long-press the ( ) of a task to give it a due date.';

  @override
  String get noResults => 'Nothing found';

  @override
  String get outline => 'Outline';

  @override
  String get overdue => 'Overdue';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get redo => 'Redo';

  @override
  String get undo => 'Undo';

  @override
  String get replace => 'Replace';

  @override
  String replaceFileQuestion(String file) {
    return '$file already exists. Replace it?';
  }

  @override
  String get search => 'Search';

  @override
  String searchHint(String workspace) {
    return 'Search in $workspace';
  }

  @override
  String get summary => 'Workspace summary';

  @override
  String get tasks => 'Tasks';

  @override
  String get uncategorized => 'Uncategorized';
}
