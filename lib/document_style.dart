import 'package:flutter/material.dart';

import 'config/concealer_config.dart';
import 'settings.dart';
import 'theme/norg_theme.dart';

class DocumentStyle {
  const DocumentStyle._(this.theme, this.icons, this.base, this.charWidth);

  factory DocumentStyle.of(BuildContext context) {
    final settings = MorgSettingsScope.of(context);
    final theme = settings.theme.of(Theme.of(context).brightness);
    final base = Theme.of(context).textTheme.bodyMedium!
        .copyWith(color: theme.foreground, height: 1.4);
    return DocumentStyle._(
      theme,
      settings.concealer,
      base,
      textWidth('M', base),
    );
  }

  final NorgTheme theme;
  final ConcealerConfig icons;
  final TextStyle base;
  final double charWidth;

  TextStyle group(String name, [TextStyle? on]) =>
      theme[name].apply(on ?? base);
}

double textWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
