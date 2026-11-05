import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/ledger.dart';

abstract class LedgerStore {
  Future<Ledger> load();
  Future<void> save(Ledger ledger);
  Future<void> close();
}

abstract class VaultKeyStore {
  Future<String?> read();
  Future<void> write(String value);
}

class DeviceKeyStore implements VaultKeyStore {
  final FlutterSecureStorage storage;
  const DeviceKeyStore([
    this.storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  ]);
  @override
  Future<String?> read() => storage.read(key: 'pocket_ledger_vault_key_v1');
  @override
  Future<void> write(String value) =>
      storage.write(key: 'pocket_ledger_vault_key_v1', value: value);
}

/// SQLite stores a single authenticated, encrypted snapshot. Atomic replacement
/// makes all financial records one transaction; no plaintext amounts enter SQLite.
class SqliteLedgerStore implements LedgerStore {
  final Database db;
  final VaultKeyStore keys;
  static final cipher = AesGcm.with256bits();
  SqliteLedgerStore(this.db, this.keys);
  static Future<SqliteLedgerStore> open({
    DatabaseFactory? factory,
    String? path,
    VaultKeyStore? keys,
  }) async {
    final f = factory ?? databaseFactory;
    final location =
        path ?? p.join(await f.getDatabasesPath(), 'pocket-ledger.db');
    final db = await f.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE vault (id INTEGER PRIMARY KEY CHECK (id = 1), payload TEXT NOT NULL)',
          );
        },
      ),
    );
    return SqliteLedgerStore(db, keys ?? const DeviceKeyStore());
  }

  Future<SecretKey> _key({required bool allowCreate}) async {
    var encoded = await keys.read();
    if (encoded == null) {
      if (!allowCreate) {
        throw const FormatException(
          'The device encryption key is unavailable. Restore an exported backup.',
        );
      }
      encoded = base64Encode(SecretKeyData.random(length: 32).bytes);
      await keys.write(encoded);
    }
    final bytes = base64Decode(encoded);
    if (bytes.length != 32) {
      throw const FormatException('Invalid device encryption key.');
    }
    return SecretKey(bytes);
  }

  @override
  Future<Ledger> load() async {
    final rows = await db.query('vault', where: 'id = 1');
    if (rows.isEmpty) return Ledger();
    final j = jsonDecode(rows.single['payload'] as String) as Map;
    final box = SecretBox(
      base64Decode(j['cipher'] as String),
      nonce: base64Decode(j['nonce'] as String),
      mac: Mac(base64Decode(j['mac'] as String)),
    );
    final bytes = await cipher.decrypt(
      box,
      secretKey: await _key(allowCreate: false),
    );
    return Ledger.fromJson(jsonDecode(utf8.decode(bytes)));
  }

  @override
  Future<void> save(Ledger ledger) async {
    ledger.validate();
    final box = await cipher.encrypt(
      utf8.encode(jsonEncode(ledger.toJson())),
      secretKey: await _key(allowCreate: true),
    );
    final payload = jsonEncode({
      'cipher': base64Encode(box.cipherText),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
    });
    await db.transaction((txn) async {
      await txn.insert('vault', {
        'id': 1,
        'payload': payload,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<void> close() => db.close();
}
