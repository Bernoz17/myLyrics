import 'dart:io';
import 'package:flutter/services.dart';

class WidgetBridge {
  static const _channel = MethodChannel('mylyrics/widget');

  static Future<void> reload() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('reload');
    } catch (_) {
      // WidgetKit will also refresh via the timeline policy.
    }
  }
}
