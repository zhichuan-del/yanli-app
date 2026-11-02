import { test } from 'node:test';
import assert from 'node:assert/strict';
import { decodePcmWav, createVoiceEngine } from './voice_engine.mjs';
function wav(samples = 16000) {
  const bytes = Buffer.alloc(44 + samples * 2);
  bytes.write('RIFF'); bytes.writeUInt32LE(bytes.length - 8, 4); bytes.write('WAVEfmt ', 8);
  bytes.writeUInt32LE(16, 16); bytes.writeUInt16LE(1, 20); bytes.writeUInt16LE(1, 22);
  bytes.writeUInt32LE(16000, 24); bytes.writeUInt32LE(32000, 28);
  bytes.writeUInt16LE(2, 32); bytes.writeUInt16LE(16, 34); bytes.write('data', 36);
  bytes.writeUInt32LE(samples * 2, 40); return bytes;
}
test('Reject malformed and truncated microphone audio', () => {
  assert.throws(() => decodePcmWav(Buffer.alloc(44)));
  assert.throws(() => decodePcmWav(wav().subarray(0, 55)));
  const stereo = wav(); stereo.writeUInt16LE(2, 22);
  assert.throws(() => decodePcmWav(stereo));
});
test('PCM conversion preserves sign and sample count', () => {
  const bytes = wav(2); bytes.writeInt16LE(-32768, 44); bytes.writeInt16LE(16384, 46);
  assert.deepEqual([...decodePcmWav(bytes)], [-1, 0.5]);
});
test('Silence returns no invented transcript', async () => {
  const recognize = await createVoiceEngine();
  assert.equal(await recognize(wav()), '');
});
