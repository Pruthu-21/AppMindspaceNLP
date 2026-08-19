import 'storage/storage_loader.dart';

class AppStorage {
  static Future<void> write(String key, String value) async {
    await platformWriteStorage(key, value);
  }

  static Future<String?> read(String key) async {
    return platformReadStorage(key);
  }

  static Future<void> delete(String key) async {
    await platformDeleteStorage(key);
  }
}
