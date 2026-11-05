import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../core/ledger.dart';

/// Same PBKDF2/AES-GCM wire format as Pocket_Ledger_Preview.html.
class BackupCodec {
  static const maxBytes = 5000000;
  static final cipher = AesGcm.with256bits();
  static final kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 600000,
    bits: 256,
  );
  static Future<SecretKey> key(String password, List<int> salt) =>
      kdf.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  static Future<String> encode(Ledger ledger, String password) async {
    if (password.length < 10) {
      throw const FormatException(
        'Use at least 10 characters for the backup password.',
      );
    }
    ledger.validate();
    final salt = SecretKeyData.random(length: 16).bytes;
    final box = await cipher.encrypt(
      utf8.encode(jsonEncode(ledger.toJson())),
      secretKey: await key(password, salt),
    );
    return jsonEncode({
      'format': 'pocket-ledger-encrypted',
      'version': 1,
      'salt': base64Encode(salt),
      'iv': base64Encode(box.nonce),
      'cipher': base64Encode([...box.cipherText, ...box.mac.bytes]),
    });
  }

  static Future<Ledger> decode(String text, String password) async {
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('Backup must be smaller than 5 MB.');
    }
    try {
      final j = jsonDecode(text) as Map;
      if (j['format'] != 'pocket-ledger-encrypted' || j['version'] != 1) {
        throw const FormatException();
      }
      final salt = base64Decode(j['salt'] as String),
          nonce = base64Decode(j['iv'] as String),
          bytes = base64Decode(j['cipher'] as String);
      if (salt.length != 16 || nonce.length != 12 || bytes.length < 16) {
        throw const FormatException();
      }
      final box = SecretBox(
        bytes.sublist(0, bytes.length - 16),
        nonce: nonce,
        mac: Mac(bytes.sublist(bytes.length - 16)),
      );
      final clear = await cipher.decrypt(
        box,
        secretKey: await key(password, salt),
      );
      return Ledger.fromJson(jsonDecode(utf8.decode(clear)));
    } catch (_) {
      throw const FormatException(
        'Incorrect password, damaged file, or unsupported backup. Nothing was changed.',
      );
    }
  }
}

String ledgerCsv(Ledger ledger) {
  String cell(Object value) {
    var s = value.toString();
    if (RegExp(r'^\s*[=+@-]').hasMatch(s)) s = "'$s";
    return '"${s.replaceAll('"', '""')}"';
  }

  final rows = <List<Object>>[
    ['Date or month', 'Type', 'Category', 'Amount', 'Currency', 'Note'],
    ...ledger.entries.map(
      (e) => [
        e.date,
        e.kind,
        ledger.category(e.category).name,
        amountText(e.amount, ledger.currency),
        ledger.currency,
        e.note,
      ],
    ),
    ...ledger.salaries.entries.map(
      (e) => [
        e.key,
        'salary',
        '',
        amountText(e.value, ledger.currency),
        ledger.currency,
        '',
      ],
    ),
    ...ledger.adjustments.map(
      (e) => [
        e.month,
        'savings adjustment',
        '',
        amountText(e.delta, ledger.currency),
        ledger.currency,
        e.note,
      ],
    ),
  ];
  return '\ufeff${rows.map((r) => r.map(cell).join(',')).join('\r\n')}';
}
