import 'package:flutter/material.dart';

import 'l10n/l10n.dart';

final themeMode = ValueNotifier(ThemeMode.system);

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? context.l10n.themeLight : context.l10n.themeDark,
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
      onPressed: () =>
          themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}
