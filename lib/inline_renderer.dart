import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'document_style.dart';
import 'norg/ast.dart';
import 'norg/targets.dart';
import 'raw_highlight.dart';

class InlineRenderer {
  const InlineRenderer({
    required this.style,
    required this.targets,
    required this.linkRecognizer,
  });

  final DocumentStyle style;
  final DocumentTargets targets;
  final GestureRecognizer Function(String target) linkRecognizer;

  TextSpan spans(List<Inline> nodes, TextStyle on) => TextSpan(
    style: on,
    children: [for (final node in nodes) inline(node, on)],
  );

  InlineSpan inline(Inline node, TextStyle on) => switch (node) {
    TextInline(:final text) ||
    TargetInline(:final text) => TextSpan(text: text),
    StyledInline(style: InlineStyle.spoiler, :final children) => TextSpan(
      text: style.icons.spoiler * plainText(children).length,
      style: style.group('@neorg.markup.spoiler', on),
    ),
    StyledInline(
      style: InlineStyle.superscript || InlineStyle.subscript,
      :final children,
    ) =>
      _shifted(node.style == InlineStyle.superscript, children, on),
    StyledInline(style: final kind, :final children) => spans(
      children,
      style.group('@neorg.markup.${kind.name}', on),
    ),
    VerbatimInline(kind: VerbatimKind.math, :final text) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: math(
        node.end - node.start - text.length == 4
            ? text
            : text.replaceAll(r'\\', r'\'),
        MathStyle.text,
        style.group('@neorg.markup.inline_math', on),
      ),
    ),
    VerbatimInline(:final kind, :final text) => TextSpan(
      text: text,
      style: style.group(switch (kind) {
        VerbatimKind.code => '@neorg.markup.verbatim',
        VerbatimKind.math => '@neorg.markup.inline_math',
        VerbatimKind.variable => '@neorg.markup.variable',
        VerbatimKind.comment => '@neorg.markup.inline_comment',
      }, on),
    ),
    AnchorInline(:final description) => switch (targets.anchorTarget(
      description,
    )) {
      final target? => _link(target, description, on),
      null => spans(description, style.group('@neorg.anchors.declaration', on)),
    },
    LinkInline(:final target, :final description) => _link(
      target,
      description,
      on,
    ),
  };

  InlineSpan _shifted(bool up, List<Inline> children, TextStyle on) {
    final size = on.fontSize ?? 14;
    final group = up ? '@neorg.markup.superscript' : '@neorg.markup.subscript';
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Transform.translate(
        offset: Offset(0, up ? -size * 0.35 : size * 0.3),
        child: Text.rich(
          spans(
            children,
            style.group(group, on.copyWith(fontSize: size * 0.7)),
          ),
        ),
      ),
    );
  }

  InlineSpan _link(String target, List<Inline> description, TextStyle on) {
    if (target.startsWith('@ ')) {
      final timestamp = style.group(linkGroup(target), on);
      return description.isEmpty
          ? TextSpan(text: target.substring(2).trim(), style: timestamp)
          : spans(description, timestamp);
    }
    final recognizer = linkRecognizer(target);
    final linkStyle = description.isEmpty
        ? style.group(linkGroup(target), on)
        : style.group('@neorg.links.description', on);
    return _withRecognizer(
      TextSpan(
        style: linkStyle,
        children: description.isEmpty
            ? [TextSpan(text: linkLabel(target))]
            : [for (final node in description) inline(node, linkStyle)],
      ),
      recognizer,
    );
  }

  InlineSpan _withRecognizer(InlineSpan span, GestureRecognizer recognizer) =>
      switch (span) {
        TextSpan() => TextSpan(
          text: span.text,
          style: span.style,
          recognizer: recognizer,
          mouseCursor: SystemMouseCursors.click,
          children: [
            for (final child in span.children ?? const <InlineSpan>[])
              _withRecognizer(child, recognizer),
          ],
        ),
        _ => span,
      };

  Widget math(String tex, MathStyle mathStyle, TextStyle on) => Math.tex(
    tex,
    mathStyle: mathStyle,
    textStyle: on,
    onErrorFallback: (_) => Text(tex, style: style.group('@neorg.error', on)),
  );
}
