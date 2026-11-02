import 'dart:js_interop';

import 'package:flutter/services.dart';

@JS('yanliVoiceStart')
external JSPromise<JSString> _start(JSFunction onPartial);
@JS('yanliVoiceStop')
external JSPromise<JSAny?> _stop();
@JS('yanliVoiceCancel')
external JSPromise<JSAny?> _cancel();

class VoiceInput {
  const VoiceInput();

  Future<String?> start({void Function(String)? onPartial}) async {
    try {
      return (await _start(
        ((JSString text) => onPartial?.call(text.toDart)).toJS,
      ).toDart).toDart;
    } catch (error) {
      throw PlatformException(code: 'local_voice', message: error.toString());
    }
  }

  Future<T?> invokeMethod<T>(String method) async {
    try {
      switch (method) {
        case 'start':
          return await start() as T?;
        case 'stop':
          await _stop().toDart;
        case 'cancel':
          await _cancel().toDart;
        default:
          throw UnsupportedError(method);
      }
      return null;
    } catch (error) {
      throw PlatformException(code: 'local_voice', message: error.toString());
    }
  }
}
