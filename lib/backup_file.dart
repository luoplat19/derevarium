import 'dart:typed_data';

import 'backup_file_native.dart'
    if (dart.library.js_interop) 'backup_file_web.dart'
    as platform;

Future<bool> saveBackupFile(Uint8List bytes, String fileName) =>
    platform.saveBackupFile(bytes, fileName);
