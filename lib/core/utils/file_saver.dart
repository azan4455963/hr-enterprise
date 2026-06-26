/// Cross-platform "save these bytes as a file".
///
/// On the web this triggers a normal browser download; on native platforms it
/// writes a temp file and opens the system share sheet. The correct
/// implementation is selected at compile time so the web build never pulls in
/// `dart:io` (which throws in a browser) and the native build never pulls in
/// the web APIs.
library;

export 'file_saver_io.dart' if (dart.library.js_interop) 'file_saver_web.dart';
