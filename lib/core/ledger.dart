import 'dart:convert';
import 'dart:math';

import 'package:intl/intl.dart';

const currencies = ['IQD', 'USD', 'EUR', 'GBP', 'AED', 'SAR'];
const maxAmount = 1000000000000;
String newId() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String monthKey(DateTime d) => dateKey(d).substring(0, 7);
String monthLabel(String m) =>
    DateFormat.yMMMM().format(DateTime.parse('$m-01'));
bool validMonth(String m) =>
    RegExp(r'^(19\d{2}|[2-9]\d{3})-(0[1-9]|1[0-2])$').hasMatch(m);
bool validDate(String s) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) ||
      !validMonth(s.substring(0, 7))) {
    return false;
  }
  final d = DateTime.tryParse(s);
  return d != null && dateKey(d) == s;
}

int currencyDigits(String c) => c == 'IQD' ? 0 : 2;
int scale(String c) => c == 'IQD' ? 1 : 100;
String amountText(int value, String c) =>
    (value / scale(c)).toStringAsFixed(currencyDigits(c));
String money(int value, String c) =>
    '${NumberFormat('#,##0${currencyDigits(c) == 0 ? '' : '.00'}', 'en_US').format(value / scale(c))} $c';
int parseMoney(String input, String c, {bool zero = false}) {
  var s = input.trim();
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i').replaceAll('۰۱۲۳۴۵۶۷۸۹'[i], '$i');
  }
  s = s.replaceAll('٫', '.');
  final digits = currencyDigits(c);
  if (!(digits == 0 ? RegExp(r'^\d+$') : RegExp(r'^\d+(\.\d{1,2})?$')).hasMatch(
    s,
  )) {
    throw FormatException(
      'Enter a valid amount${digits == 0 ? ' with no decimals' : ' with at most 2 decimals'}. Do not use thousands separators.',
    );
  }
  final parts = s.split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > maxAmount) {
    throw const FormatException('Amount is too large.');
  }
  final n =
      whole * scale(c) +
      (parts.length == 2 ? int.parse(parts[1].padRight(digits, '0')) : 0);
  if (n < (zero ? 0 : 1) || n > maxAmount) {
    throw const FormatException('Enter an amount within the supported range.');
  }
  return n;
}

class Category {
  final String id, name, icon, color;
  const Category(
    this.id,
    this.name, [
    this.icon = 'more',
    this.color = '#888078',
  ]);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
  };
  factory Category.fromJson(Map<String, dynamic> j) => Category(
    j['id'] as String,
    j['name'] as String,
    j['icon'] as String,
    j['color'] as String,
  );
}

const defaultCategories = [
  Category('food', 'Food & drinks', 'coffee', '#8b5e50'),
  Category('groceries', 'Groceries', 'bag', '#697b62'),
  Category('transport', 'Transport', 'car', '#657e8b'),
  Category('bills', 'Bills', 'bill', '#8b774e'),
  Category('shopping', 'Shopping', 'bag', '#86677e'),
  Category('health', 'Health', 'heart', '#6a8780'),
  Category('fun', 'Entertainment', 'play', '#ad7750'),
  Category('other', 'Other'),
];

class Entry {
  final String id, category, date, note, kind;
  final String? original;
  final int amount;
  const Entry({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
    this.kind = 'expense',
    this.original,
  });
  bool get refund => kind == 'refund';
  String get month => date.substring(0, 7);
  int get signed => refund ? -amount : amount;
  Entry withCategory(String value) => Entry(
    id: id,
    amount: amount,
    category: value,
    date: date,
    note: note,
    kind: kind,
    original: original,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'category': category,
    'date': date,
    'note': note,
    'kind': kind,
    'original': original,
  };
  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'] as String,
    amount: j['amount'] as int,
    category: j['category'] as String,
    date: j['date'] as String,
    note: j['note'] as String,
    kind: j['kind'] as String,
    original: j['original'] as String?,
  );
}

class SavingsAdjustment {
  final String id, month, note;
  final int delta;
  const SavingsAdjustment(this.id, this.month, this.delta, this.note);
  Map<String, dynamic> toJson() => {
    'id': id,
    'month': month,
    'delta': delta,
    'note': note,
  };
  factory SavingsAdjustment.fromJson(Map<String, dynamic> j) =>
      SavingsAdjustment(
        j['id'] as String,
        j['month'] as String,
        j['delta'] as int,
        j['note'] as String,
      );
}

class Ledger {
  String currency, theme;
  List<Category> categories;
  List<Entry> entries;
  Map<String, int> salaries, budgets;
  List<SavingsAdjustment> adjustments;
  Ledger({
    this.currency = 'IQD',
    this.theme = 'light',
    List<Category>? categories,
    List<Entry>? entries,
    Map<String, int>? salaries,
    Map<String, int>? budgets,
    List<SavingsAdjustment>? adjustments,
  }) : categories = categories ?? List.of(defaultCategories),
       entries = entries ?? [],
       salaries = salaries ?? {},
       budgets = budgets ?? {},
       adjustments = adjustments ?? [];
  bool get hasMoney =>
      entries.isNotEmpty || salaries.isNotEmpty || adjustments.isNotEmpty;
  Category category(String id) => categories.firstWhere((c) => c.id == id);
  List<Entry> inMonth(String m) =>
      entries.where((e) => e.month == m).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  int spent(String m) => inMonth(m).fold(0, (v, e) => v + e.signed);
  Map<String, dynamic> toJson() => {
    'version': 2,
    'currency': currency,
    'theme': theme,
    'categories': categories.map((x) => x.toJson()).toList(),
    'entries': entries.map((x) => x.toJson()).toList(),
    'salaries': salaries,
    'budgets': budgets,
    'savingsAdjustments': adjustments.map((x) => x.toJson()).toList(),
  };
  Ledger copy() => Ledger.fromJson(jsonDecode(jsonEncode(toJson())));
  factory Ledger.fromJson(dynamic value) {
    try {
      final j = Map<String, dynamic>.from(value as Map);
      if (j['version'] != 1 && j['version'] != 2) {
        throw const FormatException('Unsupported ledger version.');
      }
      final old = j['version'] == 1;
      final d = Ledger(
        currency: j['currency'] as String,
        theme: j['theme'] == 'dark' ? 'dark' : 'light',
        categories: (j['categories'] as List)
            .map((x) => Category.fromJson(Map<String, dynamic>.from(x as Map)))
            .toList(),
        entries: (j['entries'] as List)
            .map((x) => Entry.fromJson(Map<String, dynamic>.from(x as Map)))
            .toList(),
        salaries: old ? {} : Map<String, int>.from(j['salaries'] as Map),
        budgets: Map<String, int>.from(j['budgets'] as Map),
        adjustments: old
            ? []
            : (j['savingsAdjustments'] as List)
                  .map(
                    (x) => SavingsAdjustment.fromJson(
                      Map<String, dynamic>.from(x as Map),
                    ),
                  )
                  .toList(),
      );
      d.validate();
      return d;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid ledger data.');
    }
  }
  void validate() {
    void check(bool valid, String error) {
      if (!valid) throw FormatException(error);
    }

    check(currencies.contains(currency), 'Unsupported currency.');
    check(
      categories.isNotEmpty && categories.length <= 100,
      'Use between 1 and 100 categories.',
    );
    final ids = <String>{}, names = <String>{};
    for (final c in categories) {
      check(
        c.id.isNotEmpty &&
            ids.add(c.id) &&
            c.name.trim().isNotEmpty &&
            c.name.length <= 40 &&
            names.add(c.name.trim().toLowerCase()) &&
            RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(c.color),
        'Invalid or duplicate category.',
      );
    }
    check(
      entries.length <= 10000 && adjustments.length <= 10000,
      'Ledger supports up to 10,000 entries and savings adjustments.',
    );
    final entryMap = <String, Entry>{};
    var total = 0;
    for (final e in entries) {
      check(
        e.id.isNotEmpty &&
            !entryMap.containsKey(e.id) &&
            e.amount > 0 &&
            e.amount <= maxAmount &&
            ids.contains(e.category) &&
            validDate(e.date) &&
            e.note.length <= 200 &&
            ['expense', 'refund'].contains(e.kind),
        'Invalid expense.',
      );
      entryMap[e.id] = e;
      total += e.amount;
    }
    final refunds = <String, int>{};
    for (final e in entries.where((e) => e.refund)) {
      final parent = entryMap[e.original];
      check(
        parent != null &&
            !parent.refund &&
            parent.category == e.category &&
            e.date.compareTo(parent.date) >= 0,
        'Refund must belong to an expense and cannot be dated before it.',
      );
      refunds[parent!.id] = (refunds[parent.id] ?? 0) + e.amount;
      check(
        refunds[parent.id]! <= parent.amount,
        'Refunds cannot exceed the original expense.',
      );
    }
    for (final map in [budgets, salaries]) {
      check(map.length <= 1200, 'Too many monthly records.');
      for (final item in map.entries) {
        check(
          validMonth(item.key) && item.value >= 0 && item.value <= maxAmount,
          'Invalid monthly amount.',
        );
      }
    }
    total += salaries.values.fold(0, (a, b) => a + b);
    final adjustmentIds = <String>{};
    for (final a in adjustments) {
      check(
        a.id.isNotEmpty &&
            adjustmentIds.add(a.id) &&
            validMonth(a.month) &&
            a.delta.abs() <= 2 * maxAmount &&
            a.note.length <= 200,
        'Invalid savings adjustment.',
      );
      total += a.delta.abs();
    }
    check(total <= 9007199254740991, 'Ledger exceeds the supported total.');
  }

  void putEntry(Entry entry) {
    final index = entries.indexWhere((x) => x.id == entry.id);
    if (index < 0) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
    if (!entry.refund) {
      entries = entries
          .map(
            (e) => e.original == entry.id ? e.withCategory(entry.category) : e,
          )
          .toList();
    }
  }

  void deleteEntry(String id) =>
      entries.removeWhere((e) => e.id == id || e.original == id);
  void setSavings(String month, int target, String note) {
    if (target < 0 || target > maxAmount) {
      throw const FormatException('Savings must be zero or positive.');
    }
    final delta = target - balances(month).savings;
    if (delta != 0) {
      adjustments.add(SavingsAdjustment(newId(), month, delta, note));
    }
  }

  Balance balances(String until) {
    final spending = <String, int>{}, changes = <String, int>{};
    for (final e in entries) {
      spending.update(e.month, (v) => v + e.signed, ifAbsent: () => e.signed);
    }
    for (final a in adjustments) {
      changes.update(a.month, (v) => v + a.delta, ifAbsent: () => a.delta);
    }
    final months = {
      ...salaries.keys,
      ...spending.keys,
      ...changes.keys,
    }.where((m) => m.compareTo(until) <= 0).toList()..sort();
    var salary = 0, savings = 0;
    final rows = <MonthBalance>[];
    for (final m in months) {
      var rolled = 0, covered = 0;
      if (salaries.containsKey(m)) {
        rolled = salary;
        savings += salary;
        salary = salaries[m]!;
        if (savings < 0) {
          covered = min(salary, -savings);
          salary -= covered;
          savings += covered;
        }
      }
      final spent = spending[m] ?? 0;
      final fromSalary = spent >= 0 ? min(salary, spent) : 0;
      salary -= fromSalary;
      savings -= spent - fromSalary;
      savings += changes[m] ?? 0;
      rows.add(
        MonthBalance(
          m,
          salary,
          savings,
          rolled,
          covered,
          spent,
          fromSalary,
          salaries[m],
        ),
      );
    }
    return Balance(salary, savings, rows);
  }
}

class Balance {
  final int salary, savings;
  final List<MonthBalance> rows;
  const Balance(this.salary, this.savings, this.rows);
  int get total => salary + savings;
  int get shortfall => max(0, -savings);
}

class MonthBalance {
  final String month;
  final int salary, savings, rolled, covered, spent, fromSalary;
  final int? salaryAdded;
  const MonthBalance(
    this.month,
    this.salary,
    this.savings,
    this.rolled,
    this.covered,
    this.spent,
    this.fromSalary,
    this.salaryAdded,
  );
}
