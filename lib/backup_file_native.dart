import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

Future<bool> saveBackupFile(Uint8List bytes, String fileName) async {
  final location = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: [
      const XTypeGroup(label: 'Derevarium', extensions: ['json']),
    ],
  );
  if (location == null) return false;
  await XFile.fromData(
    bytes,
    mimeType: 'application/json',
    name: fileName,
  ).saveTo(location.path);
  return true;
}
