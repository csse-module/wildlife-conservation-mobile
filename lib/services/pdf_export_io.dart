import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<String?> exportPdf(Uint8List bytes, String filename) async {
  if (Platform.isAndroid) {
    return const MethodChannel(
      'wildguard/reports',
    ).invokeMethod<String>('savePdf', {'bytes': bytes, 'name': filename});
  }
  if (Platform.isIOS) {
    final folder = await getApplicationDocumentsDirectory();
    final output = File(path.join(folder.path, filename));
    await output.writeAsBytes(bytes, flush: true);
    return 'Saved to Files: $filename';
  }
  final destination = await getSaveLocation(
    suggestedName: filename,
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'PDF',
        extensions: ['pdf'],
        uniformTypeIdentifiers: ['com.adobe.pdf'],
      ),
    ],
  );
  if (destination == null) return null;
  await XFile.fromData(
    bytes,
    mimeType: 'application/pdf',
    name: filename,
  ).saveTo(destination.path);
  return 'Saved to ${destination.path}';
}
