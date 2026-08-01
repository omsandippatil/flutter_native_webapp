// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

final Set<String> _registeredViewTypes = {};

Widget buildYoutubeEmbed(String youtubeId) {
  final viewType = 'class-youtube-embed-$youtubeId';

  if (!_registeredViewTypes.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      return html.IFrameElement()
        ..src =
            'https://www.youtube.com/embed/$youtubeId?rel=0&modestbranding=1&playsinline=1'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
        ..allowFullscreen = true;
    });
    _registeredViewTypes.add(viewType);
  }

  return HtmlElementView(viewType: viewType);
}
