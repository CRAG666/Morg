import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:jovial_svg/jovial_svg.dart';

const _svgBounds = BoxConstraints(maxHeight: 300);

Widget svgFromBytes(Uint8List bytes) => ConstrainedBox(
  constraints: _svgBounds,
  child: ScalableImageWidget(
    si: ScalableImage.fromSvgString(utf8.decode(bytes)),
  ),
);

Widget svgFromUrl(String url) => ConstrainedBox(
  constraints: _svgBounds,
  child: ScalableImageWidget.fromSISource(
    si: ScalableImageSource.fromSvgHttpUrl(Uri.parse(url)),
  ),
);
