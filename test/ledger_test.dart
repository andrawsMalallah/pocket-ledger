import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/core/ledger.dart';

Entry expense(
  String id,
  int amount,
  String date, {
  String kind = 'expense',
  String? original,
}) => Entry(
  id: id,
  amount: amount,
  category: 'food',
  date: date,
  kind: kind,
  original: original,
);
void main() {
  test('fresh ledger has no financial records', () {
    final d = Ledger();
    d.validate();
    expect(d.hasMoney, false);
    expect(d.balances('2026-01').total, 0);
  });
  test('salary first, then savings', () {
    final d = Ledger(salaries: {'2026-01': 1000});
    d.setSavings('2026-01', 500, '');
    d.entries.add(expense('a', 1200, '2026-01-12'));
    expect(d.balances('2026-01').salary, 0);
    expect(d.balances('2026-01').savings, 300);
  });
  test('rollover is idempotent across reload', () {
    final d = Ledger(
      salaries: {'2026-01': 1000, '2026-02': 1200},
      entries: [expense('a', 200, '2026-01-02')],
    );
    for (var i = 0; i < 20; i++) {
      expect(d.balances('2026-02').savings, 800);
      expect(d.balances('2026-02').salary, 1200);
    }
    expect(d.copy().balances('2026-02').savings, 800);
  });
  test('missing salary does not roll; zero salary closes period', () {
    final d = Ledger(
      salaries: {'2026-01': 1000},
      entries: [expense('a', 300, '2026-02-02')],
    );
    expect(d.balances('2026-02').salary, 700);
    expect(d.balances('2026-02').savings, 0);
    d.salaries['2026-03'] = 0;
    expect(d.balances('2026-03').savings, 700);
  });
  test('backdated edits and deletion across year boundary', () {
    final d = Ledger(
      salaries: {'2025-12': 1000, '2026-01': 1000},
      entries: [expense('a', 200, '2025-12-02')],
    );
    d.putEntry(expense('a', 400, '2025-12-02'));
    expect(d.balances('2026-01').savings, 600);
    d.deleteEntry('a');
    expect(d.balances('2026-01').savings, 1000);
    d.salaries['2025-12'] = 700;
    expect(d.balances('2026-01').savings, 700);
  });
  test('new salary covers previous shortfall', () {
    final d = Ledger(
      entries: [expense('a', 300, '2026-01-02')],
      salaries: {'2026-02': 1000},
    );
    expect(d.balances('2026-01').shortfall, 300);
    expect(d.balances('2026-02').salary, 700);
    expect(d.balances('2026-02').savings, 0);
  });
  test('savings edits store deltas', () {
    final d = Ledger();
    d.setSavings('2026-01', 500, 'Opening');
    d.setSavings('2026-01', 800, 'Correction');
    expect(d.adjustments.map((a) => a.delta), [500, 300]);
    d.entries.add(expense('a', 100, '2026-01-02'));
    expect(d.balances('2026-01').savings, 700);
    d.setSavings('2026-01', 700, '');
    expect(d.adjustments.length, 2);
  });
  test('refund validation and credit', () {
    final d = Ledger(
      entries: [
        expense('a', 100, '2026-01-02'),
        expense('b', 70, '2026-02-02', kind: 'refund', original: 'a'),
      ],
    );
    d.validate();
    expect(d.balances('2026-02').total, -30);
    d.entries.add(
      expense('c', 40, '2026-02-03', kind: 'refund', original: 'a'),
    );
    expect(d.validate, throwsFormatException);
    d.entries.removeLast();
    d.entries[1] = expense(
      'b',
      70,
      '2025-12-02',
      kind: 'refund',
      original: 'a',
    );
    expect(d.validate, throwsFormatException);
  });
  test('deleting expense removes its refunds', () {
    final d = Ledger(
      entries: [
        expense('a', 100, '2026-01-02'),
        expense('b', 50, '2026-01-03', kind: 'refund', original: 'a'),
      ],
    );
    d.deleteEntry('a');
    expect(d.entries, isEmpty);
  });
  test('conserves money over 120 randomized months', () {
    final rng = Random(42), d = Ledger();
    var expected = 0;
    for (var i = 0; i < 120; i++) {
      final m = monthKey(DateTime(2020, i + 1)),
          salary = rng.nextInt(5000),
          spent = rng.nextInt(6000),
          delta = rng.nextInt(500) - 250;
      if (i % 3 != 0) {
        d.salaries[m] = salary;
        expected += salary;
      }
      if (spent > 0) {
        d.entries.add(expense('$i', spent, '$m-02'));
        expected -= spent;
      }
      d.adjustments.add(SavingsAdjustment('s$i', m, delta, ''));
      expected += delta;
      d.validate();
      expect(d.balances(m).total, expected);
    }
  });
  test('integer and Arabic money input', () {
    expect(parseMoney('١٢٫٣٤', 'USD'), 1234);
    expect(parseMoney('۱۲۳', 'IQD'), 123);
    for (final s in ['1.001', '1,000', '-3', '0']) {
      expect(() => parseMoney(s, 'USD'), throwsFormatException);
    }
    expect(() => parseMoney('1.1', 'IQD'), throwsFormatException);
    expect(parseMoney('0', 'USD', zero: true), 0);
  });
  test('dates and malformed backup rejected', () {
    expect(validDate('2026-02-30'), false);
    expect(validDate('2024-02-29'), true);
    expect(validMonth('2026-13'), false);
    final bad = Ledger().toJson();
    bad['salaries'] = {'2026-01': 1.2};
    expect(() => Ledger.fromJson(bad), throwsFormatException);
    expect(
      Ledger(
        categories: [const Category('a', 'Food'), const Category('b', 'food')],
      ).validate,
      throwsFormatException,
    );
  });
  test('schema v1 migration has no invented income', () {
    final old = Ledger(entries: [expense('a', 100, '2026-01-02')]).toJson();
    old['version'] = 1;
    old.remove('salaries');
    old.remove('savingsAdjustments');
    final d = Ledger.fromJson(old);
    expect(d.salaries, isEmpty);
    expect(d.entries.length, 1);
    expect(d.toJson()['version'], 2);
  });
}
