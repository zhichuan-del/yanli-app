import 'package:flutter/services.dart';

class VoiceInput {
  const VoiceInput();

  static const _channel = MethodChannel('org.yanli/voice');

  Future<String?> start({void Function(String)? onPartial}) =>
      _channel.invokeMethod<String>('start');

  Future<T?> invokeMethod<T>(String method) => _channel.invokeMethod<T>(method);
}
