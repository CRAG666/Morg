import 'package:flutter/material.dart';

import 'config/concealer_config.dart';
import 'document_style.dart';
import 'norg/ast.dart';
import 'norg/structure.dart';
import 'norg/targets.dart';

class HeadingOutline extends StatelessWidget {
  const HeadingOutline({
    super.key,
    required this.blocks,
    required this.onSelect,
  });

  final List<Block> blocks;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final style = DocumentStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final heading in headingsOf(blocks))
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(heading.line),
            child: Padding(
              padding: EdgeInsets.only(
                left: (heading.level - 1) * style.charWidth,
                bottom: 2,
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${iconForLevel(style.icons.headingIcons, heading.level)} ',
                      style: style.group(
                        '@neorg.headings.${heading.level}.prefix',
                      ),
                    ),
                    TextSpan(
                      text: plainText(heading.title),
                      style: style.group(
                        '@neorg.links.location.heading.${heading.level}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
