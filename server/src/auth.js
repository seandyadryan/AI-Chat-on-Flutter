import jwt from 'jsonwebtoken';
import { OAuth2Client } from 'google-auth-library';

import { prisma } from './db.js';

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

export async function verifyGoogleLogin(idToken) {
  if (!process.env.GOOGLE_CLIENT_ID) {
    throw new Error('GOOGLE_CLIENT_ID is not configured');
  }

  const ticket = await googleClient.verifyIdToken({
    idToken,
    audience: process.env.GOOGLE_CLIENT_ID,
  });
  const payload = ticket.getPayload();

  if (!payload?.sub || !payload.email) {
    throw new Error('Invalid Google account');
  }

  const user = await prisma.user.upsert({
    where: { googleId: payload.sub },
    update: {
      email: payload.email,
      name: payload.name ?? payload.email,
      photoUrl: payload.picture,
    },
    create: {
      googleId: payload.sub,
      email: payload.email,
      name: payload.name ?? payload.email,
      photoUrl: payload.picture,
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
