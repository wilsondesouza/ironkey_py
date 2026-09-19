import 'dart:async';
import 'package:flutter/services.dart';
import '../core/constants.dart';

class ClipboardService {
  static Timer? _clearTimer;
  static String? _lastCopiedText;

  static Future<void> copySecure(String text, {int clearSeconds = AppConstants.clipboardClearSeconds}) async {
    _clearTimer?.cancel();
    _lastCopiedText = text;

    await Clipboard.setData(ClipboardData(text: text));

    _clearTimer = Timer(Duration(seconds: clearSeconds), () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text == _lastCopiedText) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {}
      _lastCopiedText = null;
    });
  }

  static void cancelClear() {
    _clearTimer?.cancel();
    _lastCopiedText = null;
  }
}
