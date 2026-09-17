import assert from 'node:assert/strict';
import { afterEach, beforeEach, mock, test } from 'node:test';
import { askGemini, validateGeminiConfig } from '../src/gemini.js';

const originalKey = process.env.GEMINI_API_KEY;
const originalModel = process.env.GEMINI_MODEL;

beforeEach(() => {
  process.env.GEMINI_API_KEY = 'test-key';
  delete process.env.GEMINI_MODEL;
});

afterEach(() => {
  mock.restoreAll();
  for (const [name, value] of [
    ['GEMINI_API_KEY', originalKey],
    ['GEMINI_MODEL', originalModel],
  ]) {
    if (value === undefined) delete process.env[name];
    else process.env[name] = value;
  }
});

test('sends history and knowledge to Google and excludes thought text from the answer', async () => {
  const fetchMock = mock.method(globalThis, 'fetch', async (url, options) => {
    assert.equal(url, 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent');
    assert.equal(options.headers['x-goog-api-key'], 'test-key');
    assert.ok(options.signal instanceof AbortSignal);
    const body = JSON.parse(options.body);
    assert.deepEqual(body.contents, [
      { role: 'user', parts: [{ text: 'Halo' }] },
      { role: 'model', parts: [{ text: 'Hai' }] },
      { role: 'user', parts: [{ text: 'Apa nama aplikasi ini?' }] },
    ]);
    assert.match(body.systemInstruction.parts[0].text, /Indonesian/);
    assert.match(body.systemInstruction.parts[0].text, /Database knowledge:\nNeuraX/);
    return Response.json({ candidates: [{ content: { parts: [
      { text: 'internal thought', thought: true },
      { text: ' Nama ' }, { text: 'aplikasinya NeuraX. ' },
    ] } }] });
  });
  const answer = await askGemini([
    { role: 'user', content: 'Halo' },
    { role: 'assistant', content: 'Hai' },
    { role: 'user', content: 'Apa nama aplikasi ini?' },
  ], 'NeuraX');
  assert.equal(answer, 'Nama aplikasinya NeuraX.');
  assert.equal(fetchMock.mock.callCount(), 1);
});

test('supports an environment-configured model', async () => {
  process.env.GEMINI_MODEL = 'custom-model';
  mock.method(globalThis, 'fetch', async (url) => {
    assert.match(url, /\/custom-model:generateContent$/);
    return Response.json({ candidates: [{ content: { parts: [{ text: 'OK' }] } }] });
  });
  assert.equal(await askGemini([{ role: 'user', content: 'Hi' }]), 'OK');
});

test('rejects missing credentials before sending any request', async () => {
  delete process.env.GEMINI_API_KEY;
  const fetchMock = mock.method(globalThis, 'fetch');
  assert.throws(validateGeminiConfig, /GEMINI_API_KEY/);
  await assert.rejects(askGemini([]), /GEMINI_API_KEY/);
  assert.equal(fetchMock.mock.callCount(), 0);
});

for (const status of [400, 403, 429, 500]) {
  test(`handles HTTP ${status} without exposing provider error details`, async () => {
    mock.method(globalThis, 'fetch', async () => Response.json(
      { error: { message: 'Sensitive provider details and test-key' } }, { status },
    ));
    await assert.rejects(askGemini([{ role: 'user', content: 'Hi' }]), (error) => {
      assert.doesNotMatch(error.message, /Sensitive|test-key/);
      assert.match(error.message, status === 429 ? /Batas penggunaan/ : new RegExp(`HTTP ${status}`));
      return true;
    });
  });
}

for (const response of [
  { promptFeedback: { blockReason: 'SAFETY' } },
  { candidates: [{ finishReason: 'SAFETY', content: { parts: [{ text: 'blocked' }] } }] },
  { candidates: [] },
  { candidates: [{ content: { parts: [{ text: 'thought', thought: true }] } }] },
]) {
  test(`rejects blocked or empty responses: ${JSON.stringify(response)}`, async () => {
    mock.method(globalThis, 'fetch', async () => Response.json(response));
    await assert.rejects(askGemini([{ role: 'user', content: 'Hi' }]), /tidak/);
  });
}

test('returns a useful timeout error', async () => {
  mock.method(globalThis, 'fetch', async () => { throw new DOMException('expired', 'TimeoutError'); });
  await assert.rejects(askGemini([{ role: 'user', content: 'Hi' }]), /terlalu lama/);
});

test('sanitizes network and invalid JSON failures', async () => {
  for (const failure of [new TypeError('secret URL'), new SyntaxError('secret response')]) {
    mock.method(globalThis, 'fetch', async () => { throw failure; });
    await assert.rejects(askGemini([{ role: 'user', content: 'Hi' }]), /tidak dapat dihubungi/);
    mock.restoreAll();
  }
});
