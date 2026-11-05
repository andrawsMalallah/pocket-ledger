import 'package:flutter/material.dart';

import 'data/controller.dart';
import 'data/device_auth.dart';
import 'data/store.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PocketLedgerApp());
}

class PocketLedgerApp extends StatefulWidget {
  final DeviceAuth? authentication;
  final Future<LedgerStore> Function()? openStore;
  const PocketLedgerApp({super.key, this.authentication, this.openStore});
  @override
  State<PocketLedgerApp> createState() => _PocketLedgerAppState();
}

class _PocketLedgerAppState extends State<PocketLedgerApp>
    with WidgetsBindingObserver {
  late final DeviceAuth auth = widget.authentication ?? NativeDeviceAuth();
  LedgerController? controller;
  bool locked = true, authenticating = false, obscured = false;
  String? error, loadError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.removeListener(refresh);
    controller?.store.close();
    controller?.dispose();
    super.dispose();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      obscured = state != AppLifecycleState.resumed;
      if (!authenticating &&
          (state == AppLifecycleState.paused ||
              state == AppLifecycleState.hidden ||
              state == AppLifecycleState.detached)) {
        locked = true;
      }
    });
  }

  Future<void> unlock() async {
    if (authenticating) return;
    setState(() {
      authenticating = true;
      error = null;
    });
    try {
      if (!await auth.unlock()) {
        if (mounted) {
          setState(() => error = 'Not unlocked. Try again when you are ready.');
        }
        return;
      }
      if (!mounted) return;
      if (controller == null) {
        final store =
            await (widget.openStore?.call() ?? SqliteLedgerStore.open());
        controller = LedgerController(store)..addListener(refresh);
      }
      if (controller!.ledger == null) {
        try {
          await controller!.load();
          loadError = null;
        } catch (_) {
          loadError =
              'Your saved ledger could not be opened. It has not been changed. You can retry, restore an encrypted backup, or explicitly reset it.';
        }
      }
      if (mounted) setState(() => locked = false);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message.toString()
              : 'Device authentication is unavailable. Check your phone’s screen lock and biometric settings, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pocket Ledger',
    debugShowCheckedModeBanner: false,
    theme: ledgerTheme(false),
    darkTheme: ledgerTheme(true),
    themeMode: controller?.ledger?.theme == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light,
    home: controller == null
        ? const Scaffold(body: SizedBox.expand())
        : LedgerShell(
            controller: controller!,
            loadError: loadError,
            onLock: () => setState(() => locked = true),
          ),
    builder: (context, child) => Stack(
      children: [
        ExcludeSemantics(
          excluding: locked || obscured,
          child: ExcludeFocus(
            excluding: locked || obscured,
            child: IgnorePointer(ignoring: locked || obscured, child: child!),
          ),
        ),
        if (locked || obscured)
          Positioned.fill(
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.menu_book_outlined, size: 42),
                          const SizedBox(height: 32),
                          Text(
                            'Your money.\nYour space.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'POCKET LEDGER',
                            style: TextStyle(letterSpacing: 3, fontSize: 11),
                          ),
                          const SizedBox(height: 40),
                          FilledButton.tonal(
                            onPressed: authenticating || obscured
                                ? null
                                : unlock,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.all(24),
                              shape: const CircleBorder(),
                            ),
                            child: authenticating
                                ? const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: CircularProgressIndicator(),
                                  )
                                : const Icon(Icons.fingerprint, size: 52),
                          ),
                          const SizedBox(height: 18),
                          const Text('Unlock with your device'),
                          const SizedBox(height: 8),
                          const Text(
                            'Fingerprint, face recognition, or your phone’s screen lock.',
                            textAlign: TextAlign.center,
                          ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 48),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phonelink_lock_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Kept on this device'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
