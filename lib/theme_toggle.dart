import 'package:flutter/material.dart';

final themeMode = ValueNotifier(ThemeMode.system);

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Tema claro' : 'Tema oscuro',
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
      onPressed: () =>
          themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}
