(() => {
  const base = 'http://127.0.0.1:18768';
  let current = null;
  async function release(session) {
    clearTimeout(session.timer);
    session.processor?.disconnect();
    session.source?.disconnect();
    session.stream?.getTracks().forEach(track => track.stop());
    if (session.context && session.context.state !== 'closed') await session.context.close();
  }
  function wav(samples, rate) {
    const count = Math.floor(samples.length * 16000 / rate);
    const buffer = new ArrayBuffer(44 + count * 2);
    const view = new DataView(buffer);
    const text = (offset, value) => [...value].forEach((c, i) => view.setUint8(offset + i, c.charCodeAt(0)));
    text(0, 'RIFF'); view.setUint32(4, 36 + count * 2, true); text(8, 'WAVE'); text(12, 'fmt ');
    view.setUint32(16, 16, true); view.setUint16(20, 1, true); view.setUint16(22, 1, true);
    view.setUint32(24, 16000, true); view.setUint32(28, 32000, true); view.setUint16(32, 2, true);
    view.setUint16(34, 16, true); text(36, 'data'); view.setUint32(40, count * 2, true);
    for (let i = 0; i < count; i++) {
      const from = Math.floor(i * rate / 16000);
      const to = Math.min(samples.length, Math.max(from + 1, Math.floor((i + 1) * rate / 16000)));
      let sum = 0;
      for (let j = from; j < to; j++) sum += samples[j];
      const value = Math.max(-1, Math.min(1, sum / (to - from)));
      view.setInt16(44 + i * 2, value * (value < 0 ? 32768 : 32767), true);
    }
    return buffer;
  }
  async function transcribe(session) {
    if (session.inflight) return session.inflight;
    session.inflight = (async () => {
      const length = session.chunks.reduce((sum, chunk) => sum + chunk.length, 0);
      if (length < session.context.sampleRate * 0.3 || !session.heard) return;
      const samples = new Float32Array(length);
      let offset = 0;
      for (const chunk of session.chunks) { samples.set(chunk, offset); offset += chunk.length; }
      const response = await fetch(`${base}/transcribe`, {
        method: 'POST', headers: { 'Content-Type': 'audio/wav' },
        body: wav(samples, session.context.sampleRate), signal: session.abort.signal,
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || '本机识别失败');
      if (current === session) {
        session.text = result.text || '';
        session.onPartial?.(session.text);
      }
    })();
    try { await session.inflight; } finally { session.inflight = null; }
  }
  globalThis.yanliVoiceStart = async (onPartial) => {
    if (current) throw new Error('语音输入正在进行');
    const session = { chunks: [], abort: new AbortController(), onPartial, text: '', elapsed: 0, lastSpeech: 0, lastPartial: 0 };
    current = session;
    try {
      if (!navigator.mediaDevices?.getUserMedia) throw new Error('请在本机 localhost 或 127.0.0.1 页面使用语音');
      try {
        const response = await fetch(`${base}/health`, { signal: AbortSignal.timeout(4000) });
        if (!response.ok) throw new Error();
      } catch { throw new Error('本机语音服务未就绪，请通过项目的启动脚本或 F5 启动'); }
      if (current !== session) return '';
      session.stream = await navigator.mediaDevices.getUserMedia({ audio: { channelCount: 1, sampleRate: 16000, echoCancellation: true, noiseSuppression: true, autoGainControl: true } });
      if (current !== session) { await release(session); return ''; }
      session.context = new AudioContext({ sampleRate: 16000 });
      await session.context.resume();
      await session.context.audioWorklet.addModule('voice_recorder.js');
      session.source = session.context.createMediaStreamSource(session.stream);
      session.processor = new AudioWorkletNode(session.context, 'yanli-recorder');
      session.processor.port.onmessage = event => {
        if (current !== session || session.stopping) return;
        const chunk = event.data;
        session.chunks.push(chunk);
        session.elapsed += chunk.length / session.context.sampleRate;
        const rms = Math.sqrt(chunk.reduce((sum, value) => sum + value * value, 0) / chunk.length);
        if (session.elapsed < 0.4) session.noise = Math.min(session.noise ?? 0.004, rms);
        const threshold = Math.max(0.004, Math.min(0.015, (session.noise ?? 0.002) * 3));
        if (rms > threshold) { session.heard = true; session.lastSpeech = session.elapsed; }
        if (session.heard && session.elapsed - session.lastSpeech > 3.0) {
          globalThis.yanliVoiceStop().catch(() => {});
        } else if (session.heard && session.elapsed - session.lastPartial > 0.8 && !session.inflight) {
          session.lastPartial = session.elapsed;
          transcribe(session).catch(error => session.reject?.(error));
        } else if (!session.heard && session.elapsed > 8) {
          session.reject?.(new Error('没有听到声音，请检查麦克风后重试'));
        }
      };
      session.source.connect(session.processor);
      session.processor.connect(session.context.destination);
      return await new Promise((resolve, reject) => {
        session.resolve = resolve; session.reject = reject;
        session.timer = setTimeout(() => globalThis.yanliVoiceStop().catch(() => {}), 60000);
      });
    } catch (error) {
      if (current !== session) return '';
      if (error.name === 'NotAllowedError') throw new Error('请允许浏览器使用麦克风，并检查 macOS 的麦克风权限');
      if (error.name === 'NotFoundError') throw new Error('没有找到麦克风，请连接麦克风后重试');
      throw error;
    } finally {
      await release(session);
      if (current === session) current = null;
    }
  };
  globalThis.yanliVoiceStop = async () => {
    const session = current;
    if (!session || session.stopping) return;
    if (!session.resolve) throw new Error('麦克风尚未准备好，请稍后点击完成');
    session.stopping = true;
    await release(session);
    try {
      if (session.inflight) await session.inflight;
      if (current !== session) return;
      await transcribe(session);
      if (!session.text) throw new Error('没有识别到语音，请检查麦克风后重试');
      session.resolve(session.text);
    } catch (error) { session.reject(error); }
  };
  globalThis.yanliVoiceCancel = async () => {
    const session = current;
    if (!session) return;
    current = null;
    session.abort.abort();
    session.resolve?.('');
    await release(session);
  };
})();
