import 'dart:typed_data';

/// Process-memory cache for the unlocked private key.
///
/// The key must never be written to Hive or another persistent store. Closing
/// the process clears this cache and requires the encryption password again.
class DecryptedKeyCache {
  DecryptedKeyCache._();

  static Uint8List? _value;

  static bool get isUnlocked => _value != null;

  static Uint8List? get value {
    final current = _value;
    return current == null ? null : Uint8List.fromList(current);
  }

  static void store(Uint8List key) {
    clear();
    _value = Uint8List.fromList(key);
  }

  static void clear() {
    final current = _value;
    if (current != null) current.fillRange(0, current.length, 0);
    _value = null;
  }
}
