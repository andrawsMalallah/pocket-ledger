import 'package:local_auth/local_auth.dart';

abstract class DeviceAuth {
  Future<bool> unlock();
}

class NativeDeviceAuth implements DeviceAuth {
  final LocalAuthentication auth = LocalAuthentication();
  @override
  Future<bool> unlock() async {
    if (!await auth.isDeviceSupported()) {
      throw StateError(
        'Set up a screen lock (PIN, password, or fingerprint) in your phone settings, then try again.',
      );
    }
    return auth.authenticate(
      localizedReason: 'Unlock your private Pocket Ledger',
      biometricOnly: false,
      persistAcrossBackgrounding: true,
    );
  }
}
