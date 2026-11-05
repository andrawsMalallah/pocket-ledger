import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/core/ledger.dart';
import 'package:pocket_ledger/data/backup.dart';

void main() {
  test('encrypted roundtrip, tampering, wrong password', () async {
    final d = Ledger(currency: 'USD', salaries: {'2026-01': 100000});
    final text = await BackupCodec.encode(d, 'a long test password');
    expect(text, isNot(contains('salaries')));
    expect(
      (await BackupCodec.decode(text, 'a long test password')).toJson(),
      d.toJson(),
    );
    await expectLater(
      BackupCodec.decode(text, 'wrong password'),
      throwsFormatException,
    );
    final j = jsonDecode(text) as Map<String, dynamic>;
    final bytes = base64Decode(j['cipher'] as String);
    bytes[0] ^= 1;
    j['cipher'] = base64Encode(bytes);
    await expectLater(
      BackupCodec.decode(jsonEncode(j), 'a long test password'),
      throwsFormatException,
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
  test('imports actual WebCrypto fixture', () async {
    final d = await BackupCodec.decode(
      await File('test/fixtures/browser.ledger').readAsString(),
      'browser-backup-test',
    );
    expect(d.currency, 'USD');
    expect(d.salaries['2026-01'], 100000);
    expect(d.entries.single.amount, 1234);
  }, timeout: const Timeout(Duration(minutes: 2)));
  test('CSV escapes notes and neutralizes formulas', () {
    final d = Ledger(
      entries: [
        const Entry(
          id: 'a',
          amount: 1,
          category: 'food',
          date: '2026-01-01',
          note: '=SUM(1,2)\n"hello"',
        ),
      ],
    );
    expect(ledgerCsv(d), contains("'=SUM(1,2)"));
    expect(ledgerCsv(d), contains('""hello""'));
  });
}
