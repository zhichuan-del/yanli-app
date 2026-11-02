import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/document_files.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.yanli/files');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('导出传递 UTF-8 文本、文件名和 MIME 类型并返回成功', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return true;
    });
    final ok = await DocumentFiles.exportText(
      filename: '科研汇报.md',
      mime: 'text/markdown',
      content: '中文研究结果',
    );
    expect(ok, isTrue);
    expect(seen!.method, 'export');
    expect(seen!.arguments, {
      'filename': '科研汇报.md',
      'mime': 'text/markdown',
      'content': '中文研究结果',
    });
  });
  test('选择器取消时导出返回 false、导入返回 null', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(
      await DocumentFiles.exportText(
        filename: '备份.json',
        mime: 'application/json',
        content: '{}',
      ),
      isFalse,
    );
    expect(await DocumentFiles.importText(), isNull);
  });
  test('文件读取返回原文并向上报告平台错误', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'import') return '{"名称":"研历"}';
      throw PlatformException(code: 'io_error', message: '文件写入失败');
    });
    expect(await DocumentFiles.importText(), '{"名称":"研历"}');
    expect(
      () => DocumentFiles.exportText(
        filename: 'x',
        mime: 'text/plain',
        content: 'x',
      ),
      throwsA(isA<PlatformException>()),
    );
  });
}
