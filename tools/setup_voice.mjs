import { spawn } from 'node:child_process';
import { mkdir, readFile, writeFile, rename, rm } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { homedir } from 'node:os';
import path from 'node:path';

const paraformer = process.argv.includes('--paraformer');
const root = path.join(homedir(), 'Developer/yanli-tools/voice', paraformer ? 'paraformer' : 'sensevoice');
const source = paraformer
  ? 'https://huggingface.co/csukuangfj/sherpa-onnx-paraformer-zh-2023-09-14/resolve/main'
  : 'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09/resolve/main';
const checksum = paraformer
  ? 'f36a0433bcf096bd6d6f11b80a3ac8bed110bdca632fe0d731df8d1a84475945'
  : '12ca1a2ae7ecf3e0019ef2822307ee0b5cadc9196569e379b4c4026f8205276d';
async function download(url, file, range) {
  await new Promise((resolve, reject) => {
    const args = ['-fsSL', '--retry', '3', '--max-time', '300'];
    if (range) args.push('-r', range);
    const child = spawn('curl', [...args, url, '-o', file], { stdio: 'inherit' });
    child.on('error', reject);
    child.on('exit', code => code === 0 ? resolve() : reject(new Error(`下载失败: ${code}`)));
  });
}
await mkdir(root, { recursive: true });
const target = path.join(root, 'model.int8.onnx');
let existing;
try { existing = await readFile(target); } catch {}
if (!existing || createHash('sha256').update(existing).digest('hex') !== checksum) {
  const size = paraformer ? 243371218 : 237115547;
  const parts = await Promise.all(Array.from({ length: 24 }, async (_, index) => {
    const start = Math.floor(size * index / 24), end = Math.floor(size * (index + 1) / 24) - 1;
    const file = path.join(root, `model-${index}.part`);
    await download(`${source}/model.int8.onnx?part=${index}`, file, `${start}-${end}`);
    const bytes = await readFile(file);
    if (bytes.length !== end - start + 1) throw new Error('模型下载分片不完整');
    console.log(`模型下载 ${index + 1}/24`);
    return { file, bytes };
  }));
  const model = Buffer.concat(parts.map(part => part.bytes));
  if (createHash('sha256').update(model).digest('hex') !== checksum) throw new Error('模型校验失败');
  await writeFile(`${target}.part`, model);
  await rename(`${target}.part`, target);
  await Promise.all(parts.map(part => rm(part.file)));
}
await download(`${source}/tokens.txt`, path.join(root, 'tokens.txt'));
console.log(`${paraformer ? 'Paraformer' : 'SenseVoice'} 中文离线模型已就绪`);
