import 'package:flutter/foundation.dart';

/// Debug-only logger.
///
/// Debug payloads (join/sign responses, sync results, decrypted metadata) must
/// never reach release-build logs (F-37). Gate every such print behind this.
void logDebug(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(message);
  }
}