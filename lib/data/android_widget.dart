import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class AndroidWidget {
  static const channel = MethodChannel('com.yushi.yushi/widget');

  static Future<void> refresh() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await channel.invokeMethod<void>('refresh');
    } on PlatformException catch (error) {
      debugPrint('Widget refresh failed: ${error.code}');
    } on MissingPluginException {
      // Widget bridge is absent in widget tests and non-Android hosts.
    }
  }

  static Future<bool> pin() async =>
      await channel.invokeMethod<bool>('pin') ?? false;
}
