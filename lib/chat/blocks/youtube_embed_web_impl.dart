import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget buildYoutubeEmbed(String youtubeId) {
  final viewType = 'youtube-iframe-$youtubeId';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..src = 'https://www.youtube.com/embed/$youtubeId'
      ..style.border = 'none'
      ..allow = 'accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture'
      ..allowFullscreen = true;
    return iframe;
  });
  return HtmlElementView(viewType: viewType);
} 
