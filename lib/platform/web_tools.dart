// Browser helpers used when the app runs on the web. On mobile the stub
// versions are used and these features go through the native code instead.
export 'web_tools_stub.dart' if (dart.library.js_interop) 'web_tools_web.dart';
