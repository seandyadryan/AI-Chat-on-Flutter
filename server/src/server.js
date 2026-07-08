import 'dotenv/config';

import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import { z } from 'zod';

import { createFirebaseLogin, requireAuth } from './auth.js';
import { prisma } from './db.js';
import { askOllama } from './ollama.js';

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(morgan('tiny'));

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'ai-chat-api' });
});

app.post('/auth/firebase', async (req, res) => {
  const parsed = z.object({ idToken: z.string().min(20) }).safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: 'Invalid login payload' });
  }

  try {
    const { user, token } = await createFirebaseLogin(parsed.data.idToken);
    return res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        photoUrl: user.photoUrl,
      },
    });
  } catch (error) {
    return res.status(401).json({ error: error.message });
  }
});

app.get('/chat/messages', requireAuth, async (req, res) => {
  const conversation = await getOrCreateConversation(req.userId);
  const messages = await prisma.message.findMany({
    where: { conversationId: conversation.id },
    orderBy: { createdAt: 'asc' },
  });

  return res.json({ messages });
});

app.post('/chat/messages', requireAuth, async (req, res) => {
  const parsed = z
    .object({ message: z.string().trim().min(1).max(4000) })
    .safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: 'Message is required' });
  }

  try {
    const conversation = await getOrCreateConversation(req.userId);
    const userMessage = await prisma.message.create({
      data: {
        role: 'user',
        content: parsed.data.message,
        conversationId: conversation.id,
      },
    });

    const history = await prisma.message.findMany({
      where: { conversationId: conversation.id },
      orderBy: { createdAt: 'asc' },
      take: 20,
    });

    const answer = await askOllama(history);
    const assistant = await prisma.message.create({
      data: {
        role: 'assistant',
        content: answer,
        conversationId: conversation.id,
      },
    });

    return res.json({ user: userMessage, assistant });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

async function getOrCreateConversation(userId) {
  const existing = await prisma.conversation.findFirst({
    where: { userId },
    orderBy: { updatedAt: 'desc' },
  });

  if (existing) return existing;

  return prisma.conversation.create({
    data: { userId, title: 'NeuraX Chat' },
  });
}

const port = Number(process.env.PORT ?? 8080);
app.listen(port, () => {
  console.log(`NeuraX API listening on ${port}`);
});
