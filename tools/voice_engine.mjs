import sherpa from 'sherpa-onnx-node';
const { OfflineRecognizer } = sherpa;
import { homedir } from 'node:os';
import path from 'node:path';

export function decodePcmWav(wav) {
  if (wav.length < 44 || wav.toString('ascii', 0, 4) !== 'RIFF' ||
      wav.toString('ascii', 8, 12) !== 'WAVE') throw new Error('录音格式无效');
  let format, data;
  for (let offset = 12; offset + 8 <= wav.length;) {
    const name = wav.toString('ascii', offset, offset + 4);
    const size = wav.readUInt32LE(offset + 4);
    const start = offset + 8;
    if (start + size > wav.length) throw new Error('录音数据不完整');
    if (name === 'fmt ') format = wav.subarray(start, start + size);
    if (name === 'data') data = wav.subarray(start, start + size);
    offset = start + size + (size % 2);
  }
  if (!format || format.length < 16 || format.readUInt16LE(0) !== 1 ||
      format.readUInt16LE(2) !== 1 || format.readUInt32LE(4) !== 16000 ||
      format.readUInt16LE(14) !== 16 || !data || data.length % 2) throw new Error('需要 16kHz 单声道 PCM 录音');
  if (data.length > 16000 * 2 * 60) throw new Error('每次语音最多录制 60 秒');
  const samples = new Float32Array(data.length / 2);
  for (let i = 0; i < samples.length; i++) samples[i] = data.readInt16LE(i * 2) / 32768;
  return samples;
}

export async function createVoiceEngine({ model = 'paraformer' } = {}) {
  const root = path.join(homedir(), 'Developer/yanli-tools/voice', model);
  const recognizer = await OfflineRecognizer.createAsync({
    featConfig: { sampleRate: 16000, featureDim: 80 },
    modelConfig: {
      ...(model === 'paraformer'
        ? { paraformer: { model: path.join(root, 'model.int8.onnx') } }
        : { senseVoice: { model: path.join(root, 'model.int8.onnx'), language: 'zh', useInverseTextNormalization: 1 } }),
      tokens: path.join(root, 'tokens.txt'), numThreads: 4, provider: 'cpu', debug: 0,
    },
  });
  return async wav => {
    const samples = decodePcmWav(wav);
    let energy = 0;
    for (const sample of samples) energy += sample * sample;
    if (!samples.length || Math.sqrt(energy / samples.length) < 0.003) return '';
    const stream = recognizer.createStream();
    stream.acceptWaveform({ sampleRate: 16000, samples });
    const result = await recognizer.decodeAsync(stream);
    return result.text.replace(/<\|[^|]*\|>/g, '').trim();
  };
}
