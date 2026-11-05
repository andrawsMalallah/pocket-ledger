import 'dart:async';

import 'package:flutter/material.dart';

import 'data/controller.dart';
import 'data/device_auth.dart';
import 'data/store.dart';
import 'data/theme_preference.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PocketLedgerApp());
}

class PocketLedgerApp extends StatefulWidget {
  final DeviceAuth? authentication;
  final Future<LedgerStore> Function()? openStore;
  final ThemePreference? themePreference;
  const PocketLedgerApp({
    super.key,
    this.authentication,
    this.openStore,
    this.themePreference,
  });
  @override
  State<PocketLedgerApp> createState() => _PocketLedgerAppState();
}

class _PocketLedgerAppState extends State<PocketLedgerApp>
    with WidgetsBindingObserver {
  late final DeviceAuth auth = widget.authentication ?? NativeDeviceAuth();
  late final ThemePreference themePreference =
      widget.themePreference ?? const DeviceThemePreference();
  LedgerController? controller;
  bool locked = true, authenticating = false, obscured = false, starting = true;
  bool initialPromptPending = true;
  String? error, loadError, cachedTheme;
  Future<void> themeWrites = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(start());
  }

  Future<void> start() async {
    final animation = Future<void>.delayed(const Duration(milliseconds: 700));
    String? saved;
    try {
      saved = await themePreference.read();
    } catch (_) {
      /* Use the system theme if the preference is unavailable. */
    }
    await animation;
    if (!mounted) return;
    setState(() {
      if (saved == 'dark' || saved == 'light') cachedTheme = saved;
      starting = false;
    });
    if (!obscured) scheduleInitialPrompt();
  }

  void scheduleInitialPrompt() {
    if (!initialPromptPending || starting || obscured) return;
    initialPromptPending = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && locked && !obscured) {
        unawaited(unlock());
      } else if (mounted && locked) {
        initialPromptPending = true;
      }
    });
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
    if (!mounted) return;
    final saved = controller?.ledger?.theme;
    if (saved != null && saved != cachedTheme) {
      cachedTheme = saved;
      // Keep writes ordered; a storage failure must never block the ledger.
      themeWrites = themeWrites
          .then((_) => themePreference.write(saved))
          .catchError((_) {});
    }
    setState(() {});
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
    if (state == AppLifecycleState.resumed) scheduleInitialPrompt();
  }

  Future<void> unlock() async {
    if (authenticating || starting || obscured) return;
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
        if (!mounted) {
          await store.close();
          return;
        }
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
      if (mounted) setState(() => locked = obscured);
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
    themeMode: cachedTheme == 'dark'
        ? ThemeMode.dark
        : cachedTheme == 'light'
        ? ThemeMode.light
        : ThemeMode.system,
    home: controller == null
        ? const Scaffold(body: SizedBox.expand())
        : LedgerShell(
            controller: controller!,
            loadError: loadError,
            onLock: () => setState(() {
              locked = true;
              error = null;
            }),
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
              color: starting
                  ? const Color(0xff3a6351)
                  : Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: .82, end: 1),
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeOutCubic,
                            builder: (context, scale, child) => Transform.scale(
                              scale: scale,
                              child: Opacity(
                                opacity: ((scale - .82) / .18).clamp(0, 1),
                                child: child,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: Image.asset(
                                'assets/penny_logo.png',
                                width: 130,
                                height: 130,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Pocket Ledger',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: starting ? Colors.white : null,
                                ),
                          ),
                          if (!starting) ...[
                            const SizedBox(height: 34),
                            FilledButton.tonal(
                              onPressed: authenticating || obscured
                                  ? null
                                  : unlock,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.all(22),
                                shape: const CircleBorder(),
                              ),
                              child: authenticating
                                  ? const SizedBox(
                                      width: 42,
                                      height: 42,
                                      child: CircularProgressIndicator(),
                                    )
                                  : const Icon(Icons.fingerprint, size: 46),
                            ),
                            const SizedBox(height: 18),
                            const Text('Unlock with your device'),
                            const SizedBox(height: 8),
                            const Text(
                              'Use your fingerprint or phone’s screen lock.',
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
                          ],
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
