import { spawnSync } from 'node:child_process';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createVoiceEngine } from './voice_engine.mjs';

const cases = [
  ['Tingting', '今天完成了实验数据分析下一步整理科研报告'],
  ['Tingting', '导师反馈需要补充对照实验并重新检查统计显著性'],
  ['Eddy (中文（中国大陆）)', '明天下午三点和导师讨论实验结果'],
  ['Tingting', '本周阅读了三篇论文还需要修改文献综述'],
  ['Eddy (中文（中国大陆）)', '测试一下语音输入'],
  ['Tingting', '使用聚合酶链式反应检测样本比较实验组和对照组的差异'],
];
const normalize = text => [...text.replace(/[^\p{L}\p{N}]/gu, '')];
function distance(a, b) {
  a = normalize(a); b = normalize(b);
  let row = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 0; i < a.length; i++) {
    const next = [i + 1];
    for (let j = 0; j < b.length; j++) next.push(Math.min(next[j] + 1, row[j + 1] + 1, row[j] + (a[i] !== b[j])));
    row = next;
  }
  return row[b.length];
}
const directory = await mkdtemp(path.join(tmpdir(), 'yanli-asr-compare-'));
try {
  const engines = { sensevoice: await createVoiceEngine({ model: 'sensevoice' }), paraformer: await createVoiceEngine({ model: 'paraformer' }) };
  const totals = { sensevoice: 0, paraformer: 0 }; let characters = 0;
  for (const [voice, expected] of cases) {
    const audio = path.join(directory, 'test.aiff'), wav = path.join(directory, 'test.wav');
    for (const [command, args] of [['say', ['-v', voice, '-o', audio, expected]], ['afconvert', ['-f', 'WAVE', '-d', 'LEI16@16000', '-c', '1', audio, wav]]]) {
      const result = spawnSync(command, args); if (result.status !== 0) throw new Error(result.stderr.toString());
    }
    characters += normalize(expected).length;
    const output = { expected };
    for (const [name, engine] of Object.entries(engines)) {
      const start = performance.now(); const text = await engine(await readFile(wav));
      const errors = distance(expected, text); totals[name] += errors;
      output[name] = { text, errors, milliseconds: Math.round(performance.now() - start) };
    }
    console.log(JSON.stringify(output));
  }
  console.log(JSON.stringify({ characters, errors: totals, characterErrorRate: Object.fromEntries(Object.entries(totals).map(([key, errors]) => [key, errors / characters])) }));
} finally { await rm(directory, { recursive: true, force: true }); }
