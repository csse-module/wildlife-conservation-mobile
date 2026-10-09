import 'dart:typed_data';

Future<String?> exportPdf(Uint8List bytes, String filename) => Future.error(
  UnsupportedError('PDF downloads are unavailable on this platform.'),
);
