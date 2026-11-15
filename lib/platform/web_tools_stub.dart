import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/widgets.dart';

/// A file picked in the browser: its name and contents.
typedef WebPickedFile = ({String name, Uint8List bytes});

/// Not available outside the browser.
Future<WebPickedFile?> pickWebFile(String accept) async => null;

/// Not available outside the browser.
Widget webIframe(String url, {double zoom = 1}) => const SizedBox.shrink();
