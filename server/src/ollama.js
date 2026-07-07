export async function askOllama(messages) {
  const response = await fetch(`${process.env.OLLAMA_BASE_URL}/api/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: process.env.OLLAMA_MODEL ?? 'llama3.2:3b',
      stream: false,
      messages: [
        {
          role: 'system',
          content:
            'You are a helpful AI assistant. Answer clearly and naturally in Indonesian unless the user asks otherwise.',
        },
        ...messages.map((message) => ({
          role: message.role,
          content: message.content,
        })),
      ],
    }),
  });

  if (!response.ok) {
    throw new Error(`Ollama request failed: ${response.status}`);
  }

  const json = await response.json();
  return json.message?.content?.trim() || 'Maaf, saya belum punya jawaban.';
}
