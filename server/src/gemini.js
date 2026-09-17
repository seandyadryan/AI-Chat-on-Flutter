export const DEFAULT_GEMINI_MODEL = 'gemini-3.6-flash';

export function validateGeminiConfig() {
  if (!process.env.GEMINI_API_KEY?.trim()) {
    throw new Error('GEMINI_API_KEY must be configured on the API server');
  }
}

export async function askGemini(messages, knowledgeContext = '') {
  validateGeminiConfig();
  const model = process.env.GEMINI_MODEL?.trim() || DEFAULT_GEMINI_MODEL;
  const systemPrompt = [
    'You are a helpful AI assistant. Answer clearly and naturally in Indonesian unless the user asks otherwise.',
    'If the provided database knowledge contains a relevant fact, use it as the source of truth and answer confidently.',
    knowledgeContext
      ? `Database knowledge:\n${knowledgeContext}`
      : 'Database knowledge: No extra knowledge was provided.',
  ].join('\n\n');

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': process.env.GEMINI_API_KEY.trim(),
        },
        // Finish before the Flutter client's 60-second request timeout.
        signal: AbortSignal.timeout(45_000),
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: systemPrompt }] },
          contents: messages.map((message) => ({
            role: message.role === 'assistant' ? 'model' : 'user',
            parts: [{ text: message.content }],
          })),
        }),
      },
    );

    if (!response.ok) {
      // Never return provider response bodies, URLs, or credentials to clients.
      if (response.status === 429) {
        throw new Error('Batas penggunaan AI tercapai. Silakan coba lagi nanti.');
      }
      throw new Error(`Layanan AI Google gagal merespons (HTTP ${response.status}).`);
    }

    const json = await response.json();
    const candidate = json.candidates?.[0];
    if (json.promptFeedback?.blockReason || candidate?.finishReason === 'SAFETY') {
      throw new Error('Permintaan tidak dapat dijawab oleh AI. Silakan ubah pertanyaan Anda.');
    }

    const answer = candidate?.content?.parts
      ?.filter((part) => typeof part.text === 'string' && !part.thought)
      .map((part) => part.text)
      .join('')
      .trim();
    if (!answer) {
      throw new Error('Layanan AI Google tidak mengembalikan jawaban. Silakan coba lagi.');
    }
    return answer;
  } catch (error) {
    if (error.name === 'TimeoutError' || error.name === 'AbortError') {
      throw new Error('Layanan AI terlalu lama merespons. Silakan coba lagi.');
    }
    if (error instanceof TypeError || error instanceof SyntaxError) {
      throw new Error('Layanan AI Google tidak dapat dihubungi. Silakan coba lagi.');
    }
    throw error;
  }
}
