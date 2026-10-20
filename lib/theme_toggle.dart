import 'package:flutter/material.dart';

import 'l10n/l10n.dart';
import 'settings.dart';

const _cycle = {
  ThemeMode.system: ThemeMode.light,
  ThemeMode.light: ThemeMode.dark,
  ThemeMode.dark: ThemeMode.system,
};

String themeModeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l10n.themeSystem,
  ThemeMode.light => l10n.themeLight,
  ThemeMode.dark => l10n.themeDark,
};

Future<void> setThemeMode(BuildContext context, ThemeMode mode) =>
    MorgSettingsScope.controllerOf(context).setValue(['theme_mode'], mode.name);

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = MorgSettingsScope.of(context).config.themeMode;
    return IconButton(
      tooltip: themeModeLabel(context.l10n, mode),
      icon: Icon(switch (mode) {
        ThemeMode.system => Icons.brightness_auto,
        ThemeMode.light => Icons.light_mode,
        ThemeMode.dark => Icons.dark_mode,
      }),
      onPressed: () => setThemeMode(context, _cycle[mode]!),
    );
  }
}
