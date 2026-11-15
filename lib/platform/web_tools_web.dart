import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// A file picked in the browser: its name and contents.
typedef WebPickedFile = ({String name, Uint8List bytes});

/// Opens the browser's file chooser and reads the chosen file.
Future<WebPickedFile?> pickWebFile(String accept) {
  final completer = Completer<WebPickedFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;
  input.onchange = (web.Event _) {
    final file = input.files?.item(0);
    if (file == null) {
      completer.complete(null);
      return;
    }
    final reader = web.FileReader();
    reader.onload = (web.Event _) {
      final result = reader.result;
      if (result == null) {
        completer.complete(null);
        return;
      }
      final bytes = (result as JSArrayBuffer).toDart.asUint8List();
      completer.complete((name: file.name, bytes: bytes));
    }.toJS;
    reader.onerror = (web.Event _) {
      completer.complete(null);
    }.toJS;
    reader.readAsArrayBuffer(file);
  }.toJS;
  input.click();
  return completer.future;
}

final _registered = <String>{};

/// Shows [url] (YouTube, a PDF, a live stream page...) inside the app.
Widget webIframe(String url) {
  final viewType = 'epsilon-iframe-${url.hashCode}';
  if (_registered.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      return web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'autoplay; fullscreen; encrypted-media; picture-in-picture'
        ..allowFullscreen = true;
    });
  }
  return HtmlElementView(viewType: viewType);
}
