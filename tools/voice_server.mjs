import http from 'node:http';
import { createVoiceEngine } from './voice_engine.mjs';

const port = 18768;
let transcribe;
const engineReady = createVoiceEngine().then(engine => { transcribe = engine; });
engineReady.catch(error => { console.error('本机语音模型加载失败，请运行 node tools/setup_voice.mjs --paraformer:', error.message); });
let busy = false;
const server = http.createServer(async (req, res) => {
  const origin = req.headers.origin;
  if (req.headers.host !== `127.0.0.1:${port}` ||
      (origin && !/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin))) {
    res.writeHead(403).end(); return;
  }
  if (origin) res.setHeader('Access-Control-Allow-Origin', origin);
  res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Access-Control-Allow-Private-Network', 'true');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  const reply = (status, value) => { if (!res.destroyed) res.writeHead(status).end(JSON.stringify(value)); };
  if (req.method === 'OPTIONS') { res.writeHead(204).end(); return; }
  if (req.method === 'GET' && req.url === '/health') {
    try { await engineReady; reply(200, { service: 'yanli-local-voice', engine: 'sherpa-onnx-paraformer-v2', ready: true }); }
    catch { reply(503, { error: '本机语音引擎或中文模型尚未安装完成' }); }
    return;
  }
  if (req.method !== 'POST' || req.url !== '/transcribe') { reply(404, { error: 'Not found' }); return; }
  if (busy) { reply(409, { error: '语音识别正在处理，请稍后重试' }); return; }
  busy = true;
  if (!transcribe) { busy = false; reply(503, { error: '中文语音模型仍在加载，请稍后重试' }); return; }
  try {
    const chunks = [];
    let size = 0;
    for await (const chunk of req) {
      size += chunk.length;
      if (size > 2_000_000) throw new Error('每次语音最多录制 60 秒');
      chunks.push(chunk);
    }
    const wav = Buffer.concat(chunks);
    const text = await transcribe(wav);
    reply(200, { text });
  } catch (error) { reply(400, { error: error.message }); }
  finally {
    busy = false;
  }
});
server.requestTimeout = 130_000;
server.listen(port, '127.0.0.1', async () => {
  try { await engineReady; console.log('YanLi voice ready: http://127.0.0.1:18768 (Paraformer)'); }
  catch { server.close(); process.exitCode = 1; }
});
server.on('error', async (error) => {
  if (error.code === 'EADDRINUSE') {
    try {
      const result = await fetch(`http://127.0.0.1:${port}/health`);
      const data = await result.json();
      if (data.service === 'yanli-local-voice' && data.engine === 'sherpa-onnx-paraformer-v2') { console.log('YanLi voice ready: existing service'); return; }
    } catch {}
  }
  console.error('无法启动本机语音服务:', error.message);
  process.exitCode = 1;
});
