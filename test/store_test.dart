import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pocket_ledger/core/ledger.dart';
import 'package:pocket_ledger/data/store.dart';
import 'package:pocket_ledger/data/controller.dart';

class Keys implements VaultKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    value = v;
  }
}

class BrokenStore implements LedgerStore {
  @override
  Future<Ledger> load() async => Ledger();
  @override
  Future<void> save(Ledger d) async => throw StateError('disk full');
  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(sqfliteFfiInit);
  test('SQLite ciphertext roundtrip and lost key protection', () async {
    final keys = Keys();
    final store = await SqliteLedgerStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      keys: keys,
    );
    expect((await store.load()).hasMoney, false);
    await store.save(Ledger(currency: 'USD', salaries: {'2026-01': 123456}));
    expect((await store.load()).salaries['2026-01'], 123456);
    final raw = (await store.db.query('vault')).single['payload'] as String;
    expect(raw, isNot(contains('123456')));
    expect(raw, isNot(contains('salaries')));
    keys.value = null;
    await expectLater(store.load(), throwsFormatException);
    expect((await store.db.query('vault')).single['payload'], raw);
    await store.close();
  });
  test('invalid write preserves previous state', () async {
    final store = await SqliteLedgerStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      keys: Keys(),
    );
    await store.save(Ledger(salaries: {'2026-01': 1000}));
    await expectLater(
      store.save(Ledger(salaries: {'bad': -1})),
      throwsFormatException,
    );
    expect((await store.load()).salaries['2026-01'], 1000);
    await store.close();
  });
  test('failed save does not publish in-memory changes', () async {
    final c = LedgerController(BrokenStore());
    await c.load();
    await expectLater(
      c.edit((d) => d.salaries['2026-01'] = 1000),
      throwsStateError,
    );
    expect(c.ledger!.salaries, isEmpty);
    expect(c.busy, false);
    c.dispose();
  });
}
