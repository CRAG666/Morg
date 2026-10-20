import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get themeDark;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String saveFailed(String error);

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChangesTitle;

  /// No description provided for @discardChangesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Discard your changes?'**
  String get discardChangesQuestion;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @themeImported.
  ///
  /// In en, this message translates to:
  /// **'Theme \"{name}\" imported. Enable it with \"theme\": \"{name}\".'**
  String themeImported(String name);

  /// No description provided for @pickThemeFile.
  ///
  /// In en, this message translates to:
  /// **'Exported theme (.json)'**
  String get pickThemeFile;

  /// No description provided for @resetConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset configuration'**
  String get resetConfigTitle;

  /// No description provided for @resetConfigBody.
  ///
  /// In en, this message translates to:
  /// **'morg.json will be replaced with the default configuration.'**
  String get resetConfigBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @editConfig.
  ///
  /// In en, this message translates to:
  /// **'Edit configuration'**
  String get editConfig;

  /// No description provided for @editConfigSubtitle.
  ///
  /// In en, this message translates to:
  /// **'morg.json — same structure as neorg.setup()'**
  String get editConfigSubtitle;

  /// No description provided for @importTheme.
  ///
  /// In en, this message translates to:
  /// **'Import Neovim theme'**
  String get importTheme;

  /// No description provided for @currentTheme.
  ///
  /// In en, this message translates to:
  /// **'Current theme: {name}'**
  String currentTheme(String name);

  /// No description provided for @restoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore default configuration'**
  String get restoreDefaults;

  /// No description provided for @couldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open {target}'**
  String couldNotOpen(String target);

  /// No description provided for @couldNotOpenBecause.
  ///
  /// In en, this message translates to:
  /// **'Could not open {target}: {error}'**
  String couldNotOpenBecause(String target, String error);

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not found: “{location}”'**
  String notFound(String location);

  /// No description provided for @unsupportedLink.
  ///
  /// In en, this message translates to:
  /// **'Unsupported link: {target}'**
  String unsupportedLink(String target);

  /// No description provided for @noteMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'This note does not exist'**
  String get noteMissingTitle;

  /// No description provided for @createNoteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Create {path} in {location}?'**
  String createNoteQuestion(String path, String location);

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @couldNotRead.
  ///
  /// In en, this message translates to:
  /// **'Could not read: {error}'**
  String couldNotRead(String error);

  /// No description provided for @couldNotReadAt.
  ///
  /// In en, this message translates to:
  /// **'Could not read {location}:\n{error}'**
  String couldNotReadAt(String location, String error);

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get newNote;

  /// No description provided for @newNoteHint.
  ///
  /// In en, this message translates to:
  /// **'name or folder/name'**
  String get newNoteHint;

  /// No description provided for @index.
  ///
  /// In en, this message translates to:
  /// **'Index'**
  String get index;

  /// No description provided for @journalToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s journal'**
  String get journalToday;

  /// No description provided for @syncConflict.
  ///
  /// In en, this message translates to:
  /// **'Syncthing conflict'**
  String get syncConflict;

  /// No description provided for @workspaceName.
  ///
  /// In en, this message translates to:
  /// **'Workspace name'**
  String get workspaceName;

  /// No description provided for @workspaceNameHint.
  ///
  /// In en, this message translates to:
  /// **'same as in Neovim, e.g. notes'**
  String get workspaceNameHint;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @removeWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Remove “{name}”'**
  String removeWorkspace(String name);

  /// No description provided for @removeWorkspaceBody.
  ///
  /// In en, this message translates to:
  /// **'It is removed from morg.json. No files are deleted.'**
  String get removeWorkspaceBody;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @fileAccess.
  ///
  /// In en, this message translates to:
  /// **'File access'**
  String get fileAccess;

  /// No description provided for @fileAccessBody.
  ///
  /// In en, this message translates to:
  /// **'Needed for local workspaces; cloud folders work without it.'**
  String get fileAccessBody;

  /// No description provided for @grant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get grant;

  /// No description provided for @workspaces.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get workspaces;

  /// No description provided for @workspaceMissing.
  ///
  /// In en, this message translates to:
  /// **'Not on this phone · tap to choose its folder'**
  String get workspaceMissing;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open file…'**
  String get openFile;

  /// No description provided for @pickNorgFile.
  ///
  /// In en, this message translates to:
  /// **'Open a Norg file'**
  String get pickNorgFile;

  /// No description provided for @alsoFromCloud.
  ///
  /// In en, this message translates to:
  /// **'Also from the cloud'**
  String get alsoFromCloud;

  /// No description provided for @norgGuide.
  ///
  /// In en, this message translates to:
  /// **'Norg guide'**
  String get norgGuide;

  /// No description provided for @guideAsset.
  ///
  /// In en, this message translates to:
  /// **'assets/guide.norg'**
  String get guideAsset;

  /// No description provided for @importConfig.
  ///
  /// In en, this message translates to:
  /// **'Import configuration'**
  String get importConfig;

  /// No description provided for @importConfigSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace morg.json with a file, e.g. from your synced notes'**
  String get importConfigSubtitle;

  /// No description provided for @pickConfigFile.
  ///
  /// In en, this message translates to:
  /// **'Configuration file (morg.json)'**
  String get pickConfigFile;

  /// No description provided for @configImported.
  ///
  /// In en, this message translates to:
  /// **'Configuration imported'**
  String get configImported;

  /// No description provided for @invalidFile.
  ///
  /// In en, this message translates to:
  /// **'Invalid file: {error}'**
  String invalidFile(String error);

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System theme'**
  String get themeSystem;

  /// No description provided for @addWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Add workspace'**
  String get addWorkspace;

  /// No description provided for @noWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'No workspaces yet. Tap “Add workspace” and choose the folder of your notes.'**
  String get noWorkspaces;

  /// No description provided for @browseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get browseFiles;

  /// No description provided for @changeFolder.
  ///
  /// In en, this message translates to:
  /// **'Change folder'**
  String get changeFolder;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @noIndexTitle.
  ///
  /// In en, this message translates to:
  /// **'No {file} here'**
  String noIndexTitle(String file);

  /// No description provided for @noIndexBody.
  ///
  /// In en, this message translates to:
  /// **'Create it, like Neorg\'s index, or browse the workspace files?'**
  String get noIndexBody;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMode;

  /// No description provided for @colorscheme.
  ///
  /// In en, this message translates to:
  /// **'Colorscheme'**
  String get colorscheme;

  /// No description provided for @rendering.
  ///
  /// In en, this message translates to:
  /// **'Rendering (core.concealer)'**
  String get rendering;

  /// No description provided for @headingIcons.
  ///
  /// In en, this message translates to:
  /// **'Heading icons (one per level)'**
  String get headingIcons;

  /// No description provided for @listIcons.
  ///
  /// In en, this message translates to:
  /// **'List icons'**
  String get listIcons;

  /// No description provided for @quoteIcons.
  ///
  /// In en, this message translates to:
  /// **'Quote icons'**
  String get quoteIcons;

  /// No description provided for @hideCodeTags.
  ///
  /// In en, this message translates to:
  /// **'Hide @code and @end lines'**
  String get hideCodeTags;

  /// No description provided for @notesSection.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesSection;

  /// No description provided for @author.
  ///
  /// In en, this message translates to:
  /// **'Author (metagen)'**
  String get author;

  /// No description provided for @indexFile.
  ///
  /// In en, this message translates to:
  /// **'Index file'**
  String get indexFile;

  /// No description provided for @defaultWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Default workspace'**
  String get defaultWorkspace;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @journal.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get journal;

  /// No description provided for @journalFolder.
  ///
  /// In en, this message translates to:
  /// **'Journal folder'**
  String get journalFolder;

  /// No description provided for @journalStrategy.
  ///
  /// In en, this message translates to:
  /// **'Entry path'**
  String get journalStrategy;

  /// No description provided for @strategyNested.
  ///
  /// In en, this message translates to:
  /// **'2026/10/20.norg'**
  String get strategyNested;

  /// No description provided for @strategyFlat.
  ///
  /// In en, this message translates to:
  /// **'2026-10-20.norg'**
  String get strategyFlat;

  /// No description provided for @journalTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template file'**
  String get journalTemplate;

  /// No description provided for @useTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use the template'**
  String get useTemplate;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @defaultSetting.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultSetting;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
