import 'domain.dart';

/// Explicitly requested demo data only. IDs stay stable across dates/restarts.
List<ResearchRecord> generateDemoProgress(DateTime now) {
  const topics = [
    '整理研究问题与检索词',
    '完成预实验与观察记录',
    '起草研究背景',
    '清洗样本数据',
    '整理本周研究思路',
    '比较相关文献方法',
    '调整实验参数',
    '补充方法章节',
    '核对材料编码',
    '准备阶段交流提纲',
    '归纳文献证据',
    '复核实验结果',
  ];
  return List.generate(12, (index) {
    final date = DateTime(now.year, now.month, now.day - 11 + index);
    return ResearchRecord(
      id: 'yanli.demo.progress.v1.${index + 1}',
      kind: RecordKind.progress,
      date: date,
      title: '【测试】${topics[index]}',
      progressType: researchTypes[index % researchTypes.length],
      detail: '【测试】模拟科研进展：${topics[index]}，整理了阶段发现与操作记录；仅供体验，不代表真实成果。',
      problem: '【测试】模拟问题：当前材料仍需交叉核对，结论尚待验证。',
      next: '【测试】模拟下一步：补充证据并复核本次记录，形成下一阶段工作清单。',
      durationMinutes: 30 + index * 10,
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
    );
  });
}

/// Existing records and recycled IDs are reserved; never modify either source.
List<ResearchRecord> missingDemoProgress(
  List<ResearchRecord> existing, {
  required DateTime now,
  Iterable<String> reservedIds = const [],
}) {
  final occupied = {...existing.map((record) => record.id), ...reservedIds};
  return generateDemoProgress(
    now,
  ).where((record) => !occupied.contains(record.id)).toList();
}
