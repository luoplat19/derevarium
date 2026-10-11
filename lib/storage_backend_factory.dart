import 'storage_backend.dart';
import 'storage_backend_native.dart'
    if (dart.library.js_interop) 'storage_backend_web.dart'
    as platform;

CollectionBackend createCollectionBackend({
  String databaseName = 'derevarium_collection',
}) => platform.createCollectionBackend(databaseName: databaseName);
