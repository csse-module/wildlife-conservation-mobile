import 'dart:typed_data';
import 'pdf_export_stub.dart'
    if (dart.library.io) 'pdf_export_io.dart'
    if (dart.library.js_interop) 'pdf_export_web.dart'
    as platform;

Future<String?> exportPdf(Uint8List bytes, String filename) =>
    platform.exportPdf(bytes, filename);
