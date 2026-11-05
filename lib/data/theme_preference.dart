import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A non-financial display preference, readable before the vault is unlocked.
abstract class ThemePreference {
  Future<String?> read();
  Future<void> write(String theme);
}

class DeviceThemePreference implements ThemePreference {
  final FlutterSecureStorage storage;
  const DeviceThemePreference([this.storage = const FlutterSecureStorage()]);

  @override
  Future<String?> read() => storage.read(key: 'pocket_ledger_theme_v1');

  @override
  Future<void> write(String theme) =>
      storage.write(key: 'pocket_ledger_theme_v1', value: theme);
}
