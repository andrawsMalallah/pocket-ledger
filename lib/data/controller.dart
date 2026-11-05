import 'package:flutter/foundation.dart';

import '../core/ledger.dart';
import 'store.dart';

class LedgerController extends ChangeNotifier {
  final LedgerStore store;
  Ledger? ledger;
  bool busy = false;
  LedgerController(this.store);
  Future<void> load() async {
    ledger = await store.load();
    notifyListeners();
  }

  Future<void> edit(void Function(Ledger) operation) async {
    if (ledger == null) throw StateError('Unlock your ledger first.');
    final next = ledger!.copy();
    operation(next);
    await replace(next);
  }

  Future<void> replace(Ledger next) async {
    if (busy) throw StateError('Another save is in progress.');
    next.validate();
    busy = true;
    notifyListeners();
    try {
      await store.save(next);
      ledger = next;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
