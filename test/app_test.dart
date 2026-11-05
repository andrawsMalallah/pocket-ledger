import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/main.dart';
import 'package:pocket_ledger/core/ledger.dart';
import 'package:pocket_ledger/data/device_auth.dart';
import 'package:pocket_ledger/data/store.dart';
import 'package:pocket_ledger/data/theme_preference.dart';

class MemoryThemePreference implements ThemePreference {
  String? value;
  MemoryThemePreference([this.value]);
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String theme) async { value = theme; }
}

class FakeAuth implements DeviceAuth {
  bool result = true;
  @override
  Future<bool> unlock() async => result;
}

class MemoryStore implements LedgerStore {
  Ledger value = Ledger();
  @override
  Future<Ledger> load() async => value.copy();
  @override
  Future<void> save(Ledger d) async {
    value = d.copy();
  }

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('locked start, salary and expense entry, persisted theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore();
    var opened = 0;
    await tester.pumpWidget(
      PocketLedgerApp(
        authentication: FakeAuth(),
        themePreference: MemoryThemePreference(),
        openStore: () async {
          opened++;
          return store;
        },
      ),
    );
    expect(opened, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(opened, 1);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add salary'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1000');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(store.value.salaries[monthKey(DateTime.now())], 1000);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '120');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(store.value.entries.single.amount, 120);
    expect(store.value.balances(monthKey(DateTime.now())).salary, 880);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(store.value.theme, 'dark');
    await tester.tap(find.byTooltip('Lock ledger'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock with your device'), findsOneWidget);
  });
  testWidgets('cancelled authentication never opens storage', (tester) async {
    final auth = FakeAuth()..result = false;
    var opened = false;
    await tester.pumpWidget(
      PocketLedgerApp(
        authentication: auth,
        themePreference: MemoryThemePreference(),
        openStore: () async {
          opened = true;
          return MemoryStore();
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(opened, false);
    expect(
      find.text('Not unlocked. Try again when you are ready.'),
      findsOneWidget,
    );
  });
  testWidgets('saved theme is applied before authentication', (tester) async {
    final auth = FakeAuth()..result = false;
    await tester.pumpWidget(PocketLedgerApp(
      authentication: auth,
      themePreference: MemoryThemePreference('dark'),
      openStore: () async => MemoryStore(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Unlock with your device'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });
  testWidgets('backgrounding locks an open ledger', (tester) async {
    await tester.pumpWidget(
      PocketLedgerApp(
        authentication: FakeAuth(),
        themePreference: MemoryThemePreference(),
        openStore: () async => MemoryStore(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Unlock with your device'), findsOneWidget);
  });
  testWidgets('locking removes keyboard focus from an open form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      PocketLedgerApp(
        authentication: FakeAuth(),
        themePreference: MemoryThemePreference(),
        openStore: () async => MemoryStore(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add salary'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    final field = tester.widget<EditableText>(find.byType(EditableText).last);
    expect(field.focusNode.hasFocus, true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(field.focusNode.hasFocus, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Unlock with your device'), findsOneWidget);
  });
}
