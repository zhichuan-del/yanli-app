import 'package:flutter/services.dart';

/// Opens Android's system file picker; null/false means the user cancelled.
class DocumentFiles {
  static const _channel = MethodChannel('org.yanli/files');

  static Future<bool> exportText({
    required String filename,
    required String mime,
    required String content,
  }) async =>
      await _channel.invokeMethod<bool>('export', {
        'filename': filename,
        'mime': mime,
        'content': content,
      }) ??
      false;

  static Future<String?> importText() =>
      _channel.invokeMethod<String>('import');
}
