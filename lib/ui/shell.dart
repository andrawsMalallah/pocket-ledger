import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/ledger.dart';
import '../data/backup.dart';
import '../data/controller.dart';
import 'theme.dart';

Future<String> encodeBackupJob(Map<String, dynamic> args) => BackupCodec.encode(
  Ledger.fromJson(args['data']),
  args['password'] as String,
);
Future<Map<String, dynamic>> decodeBackupJob(Map<String, String> args) async =>
    (await BackupCodec.decode(args['text']!, args['password']!)).toJson();

class LedgerShell extends StatefulWidget {
  final LedgerController controller;
  final VoidCallback onLock;
  final String? loadError;
  const LedgerShell({
    super.key,
    required this.controller,
    required this.onLock,
    this.loadError,
  });
  @override
  State<LedgerShell> createState() => _LedgerShellState();
}

class _LedgerShellState extends State<LedgerShell> {
  LedgerController get c => widget.controller;
  Ledger get d => c.ledger!;
  int tab = 0;
  String month = monthKey(DateTime.now()), query = '', category = '';
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String cash(int n) => money(n, d.currency);
  void message(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    }
  }

  Future<void> action(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      message(
        e is FormatException
            ? e.message
            : 'This action could not be completed. Your last saved ledger is unchanged.',
      );
    }
  }

  Future<bool> confirm(
    String title,
    String body, {
    String button = 'Continue',
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(button),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> editor(
    String title,
    Widget Function(void Function(VoidCallback)) fields,
    Future<void> Function() save, {
    String button = 'Save',
    List<Widget> extra = const [],
  }) async {
    String? error;
    var busy = false;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    fields(setLocal),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                          ),
                        ),
                      ),
                    ...extra,
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        FocusScope.of(ctx).unfocus();
                        setLocal(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await save();
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            setLocal(() {
                              error = e is FormatException
                                  ? e.message
                                  : 'Could not save. Nothing was changed. Please try again.';
                              busy = false;
                            });
                          }
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(button),
              ),
            ],
          ),
        ),
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(route);
    // Controllers belong to callers. Keep them alive through the exit animation.
    await route.completed;
  }

  Widget field(
    TextEditingController controller,
    String label, {
    bool amount = false,
    bool secret = false,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      obscureText: secret,
      autocorrect: !secret && !amount,
      enableSuggestions: !secret && !amount,
      keyboardType: amount
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      maxLength: maxLength,
    ),
  );
  Widget note(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
  Widget title(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    ),
  );
  Widget panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
  Widget empty(String heading, String body, {Widget? button}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Column(
      children: [
        const Icon(Icons.menu_book_outlined, size: 36),
        const SizedBox(height: 12),
        Text(
          heading,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(body, textAlign: TextAlign.center),
        if (button != null)
          Padding(padding: const EdgeInsets.only(top: 18), child: button),
      ],
    ),
  );
  Future<void> salary() async {
    final m = month, exists = d.salaries.containsKey(month);
    final value = TextEditingController(
      text: exists ? amountText(d.salaries[m]!, d.currency) : '',
    );
    await editor(
      exists ? 'Edit monthly salary' : 'Add monthly salary',
      (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          note(monthLabel(m)),
          field(value, 'Salary · ${d.currency}', amount: true),
          note(
            'Adding a salary for a later month moves the previous unused salary into savings. Enter 0 for a month with no salary. Existing shortfalls are covered first.',
          ),
        ],
      ),
      () async {
        final amount = parseMoney(value.text, d.currency, zero: true);
        await c.edit((next) => next.salaries[m] = amount);
      },
    );
    value.dispose();
  }

  Future<void> savings() async {
    final m = month;
    final value = TextEditingController(
          text: amountText(max(0, d.balances(m).savings), d.currency),
        ),
        reason = TextEditingController();
    await editor(
      'Edit savings',
      (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          note(
            'Balance as of ${monthLabel(m)}. This records an adjustment; editing earlier transactions will still recalculate your balance.',
          ),
          field(value, 'New savings balance · ${d.currency}', amount: true),
          field(reason, 'Note (optional)', maxLength: 200),
        ],
      ),
      () async {
        final target = parseMoney(value.text, d.currency, zero: true);
        await c.edit((next) => next.setSavings(m, target, reason.text.trim()));
      },
    );
    value.dispose();
    reason.dispose();
  }

  Future<void> budget() async {
    final m = month,
        value = TextEditingController(
          text: amountText(d.budgets[month] ?? 0, d.currency),
        );
    await editor(
      'Monthly spending limit',
      (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          note(
            '${monthLabel(m)}. This is a spending guide, not additional money. Enter 0 to turn it off.',
          ),
          field(value, 'Limit · ${d.currency}', amount: true),
        ],
      ),
      () async {
        final amount = parseMoney(value.text, d.currency, zero: true);
        await c.edit((next) => next.budgets[m] = amount);
      },
    );
    value.dispose();
  }

  Future<void> expense({Entry? entry, Entry? refundFor}) async {
    final isRefund = refundFor != null || entry?.refund == true;
    final original =
        refundFor ??
        (entry?.original == null
            ? null
            : d.entries.firstWhere((e) => e.id == entry!.original));
    final value = TextEditingController(
          text: entry == null ? '' : amountText(entry.amount, d.currency),
        ),
        reason = TextEditingController(text: entry?.note ?? '');
    var selectedCategory =
        entry?.category ?? original?.category ?? d.categories.first.id;
    var date =
        entry?.date ??
        (month == monthKey(DateTime.now())
            ? dateKey(DateTime.now())
            : '$month-01');
    if (original != null && date.compareTo(original.date) < 0) {
      date = original.date;
    }
    await editor(
      entry != null
          ? 'Edit ${isRefund ? 'refund' : 'expense'}'
          : isRefund
          ? 'Record a refund'
          : 'A new expense',
      (setLocal) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field(value, 'Amount · ${d.currency}', amount: true),
          DropdownButtonFormField<String>(
            initialValue: selectedCategory,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category'),
            items: d.categories
                .map(
                  (cat) =>
                      DropdownMenuItem(value: cat.id, child: Text(cat.name)),
                )
                .toList(),
            onChanged: isRefund
                ? null
                : (v) => setLocal(() => selectedCategory = v!),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(DateFormat.yMMMd().format(DateTime.parse(date))),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(date),
                firstDate: DateTime(1900),
                lastDate: DateTime(9999, 12, 31),
              );
              if (picked != null) setLocal(() => date = dateKey(picked));
            },
          ),
          const SizedBox(height: 16),
          field(reason, 'Note (optional)', maxLength: 200),
          if (isRefund)
            note(
              'Refunds stay linked to the original expense and cannot exceed its amount. A net refund in a later month is credited to savings.',
            ),
        ],
      ),
      () async {
        final e = Entry(
          id: entry?.id ?? newId(),
          amount: parseMoney(value.text, d.currency),
          category: selectedCategory,
          date: date,
          note: reason.text.trim(),
          kind: isRefund ? 'refund' : 'expense',
          original: original?.id,
        );
        await c.edit((next) => next.putEntry(e));
        if (mounted) setState(() => month = e.month);
      },
    );
    value.dispose();
    reason.dispose();
  }

  Future<void> entryMenu(Entry e) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                e.note.isEmpty ? d.category(e.category).name : e.note,
              ),
              subtitle: Text('${cash(e.amount)} · ${e.date}'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit entry'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            if (!e.refund)
              ListTile(
                leading: const Icon(Icons.undo_outlined),
                title: const Text('Record refund'),
                onTap: () => Navigator.pop(ctx, 'refund'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete entry'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'edit') await expense(entry: e);
    if (choice == 'refund') await expense(refundFor: e);
    if (choice == 'delete' &&
        await confirm(
          'Delete this entry?',
          e.refund
              ? 'The refund will be removed and balances recalculated.'
              : 'This expense and any linked refunds will be removed. Balances will be recalculated.',
          button: 'Delete',
        )) {
      await action(() => c.edit((next) => next.deleteEntry(e.id)));
    }
  }

  Widget transaction(Entry e) => Column(
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .09),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(categoryIcon(d.category(e.category).icon)),
        ),
        title: Text(
          e.note.isEmpty ? d.category(e.category).name : e.note,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${d.category(e.category).name} · ${DateFormat.MMMd().format(DateTime.parse(e.date))}${e.refund ? ' · Refund' : ''}',
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 145),
          child: Text(
            '${e.refund ? '+' : '−'}${cash(e.amount)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: e.refund ? Theme.of(context).colorScheme.primary : null,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: () => entryMenu(e),
      ),
      const Divider(height: 1),
    ],
  );
  void moveMonth(int by) {
    final date = DateTime.parse('$month-01'),
        next = monthKey(DateTime(date.year, date.month + by));
    if (validMonth(next)) setState(() => month = next);
  }

  Widget monthPicker() => Row(
    children: [
      IconButton(
        tooltip: 'Previous month',
        onPressed: () => moveMonth(-1),
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: TextButton(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.parse('$month-01'),
              firstDate: DateTime(1900),
              lastDate: DateTime(9999, 12, 31),
              initialDatePickerMode: DatePickerMode.year,
            );
            if (date != null && mounted) setState(() => month = monthKey(date));
          },
          child: Text(monthLabel(month), textAlign: TextAlign.center),
        ),
      ),
      IconButton(
        tooltip: 'Next month',
        onPressed: () => moveMonth(1),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
  Widget overview() {
    final balance = d.balances(month),
        entries = d.inMonth(month),
        spent = d.spent(month),
        limit = d.budgets[month] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'A little clarity,\nevery day.',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 10),
        const Text('Your salary, spending, and savings. Simply kept.'),
        const SizedBox(height: 14),
        monthPicker(),
        const SizedBox(height: 18),
        const Text(
          'AVAILABLE BALANCE',
          style: TextStyle(fontSize: 10, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            cash(balance.total),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w400,
              letterSpacing: -1.7,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (balance.shortfall > 0)
          note(
            '${cash(balance.shortfall)} shortfall. Your next salary will cover this first.',
          ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Salary remaining'),
          subtitle: Text(
            d.salaries.containsKey(month)
                ? 'Monthly salary: ${cash(d.salaries[month]!)}'
                : 'No salary recorded for this month',
          ),
          trailing: Text(cash(balance.salary)),
          onTap: salary,
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: salary,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                d.salaries.containsKey(month) ? 'Edit salary' : 'Add salary',
              ),
            ),
            OutlinedButton.icon(
              onPressed: savings,
              icon: const Icon(Icons.savings_outlined, size: 18),
              label: const Text('Edit savings'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.savings_outlined, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'SAVINGS',
                    style: TextStyle(fontSize: 10, letterSpacing: 2),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                cash(balance.savings),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Unused salary moves here when you add the next month’s salary.',
              ),
            ],
          ),
        ),
        title(
          'This month',
          trailing: TextButton(
            onPressed: budget,
            child: Text(limit > 0 ? 'Edit limit' : 'Set limit'),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Net spending'),
            Text(
              cash(spent),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (limit > 0) ...[
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: (spent / limit).clamp(0.0, 1.0),
            minHeight: 5,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 9),
          Text(
            spent > limit
                ? '${cash(spent - limit)} above your limit'
                : '${cash(limit - spent)} left of ${cash(limit)}',
          ),
        ],
        title(
          'Recent entries',
          trailing: TextButton(
            onPressed: () => setState(() => tab = 1),
            child: const Text('View all'),
          ),
        ),
        if (entries.isEmpty)
          empty(
            'A fresh page.',
            'Add your salary and savings, then record your first expense.',
            button: FilledButton.icon(
              onPressed: () => expense(),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            ),
          )
        else
          ...entries.take(5).map(transaction),
        title('Money activity'),
        if (!d.hasMoney)
          note(
            'Salary payments, savings edits, and rollovers will appear here.',
          )
        else
          ...activity(),
      ],
    );
  }

  List<Widget> activity() {
    final rows = <Widget>[];
    for (final b in d.balances(month).rows.reversed.take(12)) {
      if (b.salaryAdded != null) {
        rows.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text('Salary · ${monthLabel(b.month)}'),
            subtitle: Text(
              [
                if (b.rolled > 0) '${cash(b.rolled)} moved to savings',
                if (b.covered > 0) '${cash(b.covered)} covered a shortfall',
              ].join('\n'),
            ),
            trailing: Text(cash(b.salaryAdded!)),
            onTap: () async {
              setState(() => month = b.month);
              await salary();
            },
          ),
        );
      }
      for (final a
          in d.adjustments.where((a) => a.month == b.month).toList().reversed) {
        rows.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.savings_outlined),
            title: Text('Savings adjustment · ${monthLabel(a.month)}'),
            subtitle: Text(
              a.note.isEmpty ? 'Manual balance adjustment' : a.note,
            ),
            trailing: Text('${a.delta >= 0 ? '+' : ''}${cash(a.delta)}'),
            onTap: () async {
              if (await confirm(
                'Remove savings adjustment?',
                'This reverses the adjustment and recalculates later balances.',
                button: 'Remove',
              )) {
                await action(
                  () => c.edit(
                    (next) => next.adjustments.removeWhere((x) => x.id == a.id),
                  ),
                );
              }
            },
          ),
        );
      }
    }
    return rows;
  }

  Widget history() {
    final list = d
        .inMonth(month)
        .where(
          (e) =>
              (category.isEmpty || e.category == category) &&
              ('${e.note} ${d.category(e.category).name} ${e.kind}')
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your ledger.', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 16),
        monthPicker(),
        const SizedBox(height: 12),
        TextField(
          controller: search,
          decoration: const InputDecoration(
            labelText: 'Search entries',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (s) => setState(() => query = s),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            const DropdownMenuItem(value: '', child: Text('All categories')),
            ...d.categories.map(
              (cat) => DropdownMenuItem(value: cat.id, child: Text(cat.name)),
            ),
          ],
          onChanged: (v) => setState(() => category = v!),
        ),
        title(
          '${list.length} ${list.length == 1 ? 'entry' : 'entries'}',
          trailing: Text(cash(list.fold(0, (sum, e) => sum + e.signed))),
        ),
        if (list.isEmpty)
          empty(
            'Nothing here yet.',
            query.isNotEmpty || category.isNotEmpty
                ? 'Try another search or category.'
                : 'Expenses for this month will appear here.',
          )
        else
          ...list.map(transaction),
      ],
    );
  }

  Widget insights() {
    final list = d.inMonth(month), totals = <String, int>{};
    for (final e in list) {
      totals.update(e.category, (n) => n + e.signed, ifAbsent: () => e.signed);
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxTotal = max(
      1,
      sorted.fold<int>(0, (n, e) => max(n, e.value.abs())),
    );
    final selected = DateTime.parse('$month-01');
    final months = List.generate(
      6,
      (i) => monthKey(DateTime(selected.year, selected.month - 5 + i)),
    );
    final maxSpend = max(
      1,
      months.fold<int>(0, (n, m) => max(n, d.spent(m).abs())),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'The bigger picture.',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 16),
        monthPicker(),
        title('Spending by category'),
        if (list.isEmpty)
          empty(
            'Room for perspective.',
            'Add expenses to see where your money goes.',
          )
        else
          ...sorted.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(categoryIcon(d.category(e.key).icon), size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d.category(e.key).name)),
                      Text(cash(e.value)),
                    ],
                  ),
                  const SizedBox(height: 9),
                  LinearProgressIndicator(
                    value: e.value.abs() / maxTotal,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
        title('Six-month view'),
        note(
          'Net spending after refunds. Negative amounts mean refunds exceeded spending.',
        ),
        ...months.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat.yMMM().format(DateTime.parse('$m-01'))),
                    Text(cash(d.spent(m))),
                  ],
                ),
                const SizedBox(height: 7),
                LinearProgressIndicator(
                  value: d.spent(m).abs() / maxSpend,
                  minHeight: 6,
                  color: m == month
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> editCategory([Category? cat]) async {
    final name = TextEditingController(text: cat?.name ?? '');
    await editor(
      cat == null ? 'Add category' : 'Rename category',
      (_) => field(name, 'Category name', maxLength: 40),
      () async {
        final value = name.text.trim();
        if (value.isEmpty) {
          throw const FormatException('Enter a category name.');
        }
        await c.edit((next) {
          if (cat == null) {
            next.categories.add(Category(newId(), value));
          } else {
            next.categories = next.categories
                .map(
                  (x) => x.id == cat.id
                      ? Category(x.id, value, x.icon, x.color)
                      : x,
                )
                .toList();
          }
        });
      },
    );
    name.dispose();
  }

  Future<void> currency() async {
    if (d.hasMoney) {
      message(
        'Currency is fixed while financial records exist. Export a backup and reset the ledger to start with another currency.',
      );
      return;
    }
    var selected = d.currency;
    await editor(
      'Choose currency',
      (setLocal) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: selected,
            items: currencies
                .map((code) => DropdownMenuItem(value: code, child: Text(code)))
                .toList(),
            onChanged: (v) => setLocal(() => selected = v!),
          ),
          const SizedBox(height: 16),
          note(
            'Amounts are not converted. Changing currency clears spending limits. IQD uses whole dinars.',
          ),
        ],
      ),
      () => c.edit((next) {
        next.currency = selected;
        next.budgets.clear();
      }),
    );
  }

  Future<void> exportBackup() async {
    final pass = TextEditingController(), repeat = TextEditingController();
    String? encrypted;
    await editor(
      'Keep a safe copy',
      (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          note(
            'Choose a password of at least 10 characters. Keep it safe: it cannot be recovered. Save a copy somewhere other than this phone.',
          ),
          field(pass, 'Backup password', secret: true),
          field(repeat, 'Confirm password', secret: true),
        ],
      ),
      () async {
        if (pass.text != repeat.text) {
          throw const FormatException('Passwords do not match.');
        }
        encrypted = await compute(encodeBackupJob, {
          'data': d.toJson(),
          'password': pass.text,
        });
      },
      button: 'Encrypt backup',
    );
    pass.dispose();
    repeat.dispose();
    if (encrypted == null) return;
    await action(() async {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save encrypted backup',
        fileName: 'pocket-ledger-${dateKey(DateTime.now())}.ledger',
        bytes: Uint8List.fromList(utf8.encode(encrypted!)),
      );
      if (result != null) message('Encrypted backup exported.');
    });
  }

  Future<void> restore() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.any,
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    if (file.size > BackupCodec.maxBytes || file.bytes == null) {
      message('Choose a readable backup smaller than 5 MB.');
      return;
    }
    final text = utf8.decode(file.bytes!, allowMalformed: false);
    final pass = TextEditingController();
    Ledger? imported;
    await editor(
      'Open encrypted backup',
      (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          note(
            'Selected: ${file.name}. Backups from the original browser app are supported.',
          ),
          field(pass, 'Backup password', secret: true),
        ],
      ),
      () async {
        imported = Ledger.fromJson(
          await compute(decodeBackupJob, {'text': text, 'password': pass.text}),
        );
      },
      button: 'Validate backup',
    );
    pass.dispose();
    if (imported == null || !mounted) return;
    final data = imported!;
    if (await confirm(
      'Replace this ledger?',
      'The backup contains ${data.entries.length} entries, ${data.salaries.length} salary records, and ${data.adjustments.length} savings adjustments in ${data.currency}. Your current ledger will be replaced. Export it first if needed.',
      button: 'Replace ledger',
    )) {
      await c.replace(data);
      if (mounted) {
        setState(() {
          month = monthKey(DateTime.now());
          tab = 0;
          category = '';
          query = '';
          search.clear();
        });
      }
      message('Backup restored.');
    }
  }

  Future<void> exportCsv() async {
    if (!await confirm(
      'Export an unencrypted CSV?',
      'This spreadsheet file contains your financial records in readable text. Use an encrypted backup for private storage.',
      button: 'Export CSV',
    )) {
      return;
    }
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV',
      fileName: 'pocket-ledger-${dateKey(DateTime.now())}.csv',
      bytes: Uint8List.fromList(utf8.encode(ledgerCsv(d))),
    );
    if (result != null) message('CSV exported.');
  }

  Future<void> reset() async {
    final value = TextEditingController();
    await editor(
      'Delete the local ledger',
      (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          note(
            'This permanently replaces all local financial records. Export a backup first. Existing exported files are not deleted.',
          ),
          field(value, 'Type DELETE to confirm'),
        ],
      ),
      () async {
        if (value.text != 'DELETE') {
          throw const FormatException('Type DELETE exactly.');
        }
        await c.replace(Ledger(currency: c.ledger?.currency ?? 'IQD'));
        if (mounted) {
          setState(() {
            tab = 0;
            category = '';
            query = '';
            search.clear();
            month = monthKey(DateTime.now());
          });
        }
      },
      button: 'Delete ledger',
    );
    value.dispose();
  }

  Widget settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Make it yours.', style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: 18),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.payments_outlined),
        title: const Text('Currency'),
        subtitle: Text(d.currency),
        trailing: const Icon(Icons.chevron_right),
        onTap: currency,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.dark_mode_outlined),
        title: const Text('Dark appearance'),
        value: d.theme == 'dark',
        onChanged: c.busy
            ? null
            : (value) => action(
                () => c.edit((next) => next.theme = value ? 'dark' : 'light'),
              ),
      ),
      title(
        'Categories',
        trailing: TextButton.icon(
          onPressed: () => editCategory(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
        ),
      ),
      ...d.categories.map(
        (cat) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(categoryIcon(cat.icon)),
          title: Text(cat.name),
          trailing: const Icon(Icons.edit_outlined, size: 18),
          onTap: () => editCategory(cat),
        ),
      ),
      title('Your data'),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.lock_outline),
        title: const Text('Export encrypted backup'),
        subtitle: const Text('Password-protected copy of the whole ledger'),
        onTap: () => action(exportBackup),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.restore),
        title: const Text('Restore a backup'),
        subtitle: const Text('Validate and replace local records'),
        onTap: () => action(restore),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.table_chart_outlined),
        title: const Text('Export CSV'),
        subtitle: const Text('Readable spreadsheet · not encrypted'),
        onTap: () => action(exportCsv),
      ),
      title('Private by design'),
      panel(
        const Text(
          'Your ledger is stored in an encrypted database on this device. There are no accounts, ads, analytics, or cloud sync. The app locks when it goes into the background. Your phone handles fingerprint or passcode authentication.\n\nUninstalling the app or losing this phone can lose your records. Keep an encrypted backup elsewhere. Backups you export are outside the app’s control.',
        ),
      ),
      const SizedBox(height: 22),
      OutlinedButton.icon(
        onPressed: reset,
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete local ledger'),
      ),
      const SizedBox(height: 18),
      TextButton(
        onPressed: () => showLicensePage(
          context: context,
          applicationName: 'Penny',
          applicationVersion: '1.0.0',
        ),
        child: const Text('Open-source licenses'),
      ),
      const Text(
        'Penny · 1.0.0\nMade for a clearer everyday.',
        textAlign: TextAlign.center,
      ),
    ],
  );
  Widget recovery() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_reset, size: 44),
            const SizedBox(height: 20),
            Text(
              'Your ledger needs attention.',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              widget.loadError ??
                  'Your data could not be read. Nothing has been overwritten.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => action(c.load),
              child: const Text('Retry opening'),
            ),
            TextButton(
              onPressed: () => action(restore),
              child: const Text('Restore encrypted backup'),
            ),
            TextButton(
              onPressed: reset,
              child: const Text('Explicitly reset local ledger'),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          Icon(Icons.menu_book_outlined, size: 23),
          SizedBox(width: 9),
          Text(
            'Penny',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Lock ledger',
          onPressed: widget.onLock,
          icon: const Icon(Icons.lock_outline),
        ),
      ],
    ),
    body: c.ledger == null
        ? recovery()
        : SafeArea(
            top: false,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: SingleChildScrollView(
                      key: ValueKey(tab),
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 100),
                      child: [overview, history, insights, settings][tab](),
                    ),
                  ),
                ),
                if (c.busy)
                  const Align(
                    alignment: Alignment.topCenter,
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
    floatingActionButton: c.ledger == null || tab == 3
        ? null
        : FloatingActionButton.extended(
            onPressed: c.busy ? null : () => expense(),
            icon: const Icon(Icons.add),
            label: const Text('Expense'),
          ),
    bottomNavigationBar: c.ledger == null
        ? null
        : NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (value) => setState(() => tab = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                label: 'Ledger',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                label: 'Insights',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                label: 'Settings',
              ),
            ],
          ),
  );
}
