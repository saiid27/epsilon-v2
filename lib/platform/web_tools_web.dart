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

/// Saves [bytes] as a download named [name] in the browser.
void downloadWebFile(Uint8List bytes, String name, String mimeType) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = name
    ..click();
  web.URL.revokeObjectURL(url);
}

final _registered = <String>{};

/// Shows [url] (YouTube, a PDF, a live stream page...) inside the app.
/// A [zoom] below 1 shrinks a desktop-only site so it fits a phone screen.
Widget webIframe(String url, {double zoom = 1}) {
  final viewType = 'epsilon-iframe-${url.hashCode}-$zoom';
  if (_registered.add(viewType)) {
    final size = '${(100 / zoom).toStringAsFixed(2)}%';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final frame = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = size
        ..style.height = size
        ..allow = 'autoplay; fullscreen; encrypted-media; picture-in-picture'
        ..allowFullscreen = true;
      if (zoom != 1) {
        frame.style
          ..transform = 'scale($zoom)'
          ..transformOrigin = 'top left';
      }
      return frame;
    });
  }
  return HtmlElementView(viewType: viewType);
}
