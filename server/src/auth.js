import jwt from 'jsonwebtoken';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

import { prisma } from './db.js';

const firebaseProjectId =
  process.env.FIREBASE_PROJECT_ID ?? 'ai-app-flutter-4763f';

if (!getApps().length) {
  initializeApp({
    projectId: firebaseProjectId,
  });
}

export async function createFirebaseLogin(idToken) {
  const decoded = await getAuth().verifyIdToken(idToken);
  if (!decoded.uid || !decoded.email) {
    throw new Error('Akun Google tidak valid');
  }

  const user = await prisma.user.upsert({
    where: { googleId: decoded.uid },
    update: {
      email: decoded.email,
      name: decoded.name ?? decoded.email,
      photoUrl: decoded.picture,
    },
    create: {
      googleId: decoded.uid,
      email: decoded.email,
      name: decoded.name ?? decoded.email,
      photoUrl: decoded.picture,
    },
  });

  return { user, token: signToken(user.id) };
}

export function signToken(userId) {
  return jwt.sign({ sub: userId }, process.env.JWT_SECRET, {
    expiresIn: '14d',
  });
}

export function requireAuth(req, res, next) {
  const header = req.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Missing token' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.sub;
    return next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}
