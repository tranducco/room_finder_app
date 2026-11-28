import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final Set<String> _registeredViewTypes = <String>{};

/// Nhúng Google Maps tương tác trực tiếp bằng iframe trên Flutter Web.
Widget buildRoomMapEmbed({
  required String embedUrl,
  required String fullAddress,
  required String district,
  required VoidCallback onOpenMap,
}) {
  final viewType = 'room-gmap-${embedUrl.hashCode}';

  if (!_registeredViewTypes.contains(viewType)) {
    _registeredViewTypes.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = embedUrl
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;
      iframe.setAttribute('loading', 'lazy');
      iframe.setAttribute('referrerpolicy', 'no-referrer-when-downgrade');
      return iframe;
    });
  }

  return HtmlElementView(viewType: viewType);
}
