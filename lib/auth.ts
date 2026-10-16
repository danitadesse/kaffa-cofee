import { createHmac, randomBytes, scryptSync, timingSafeEqual } from "crypto";
import { cookies } from "next/headers";

const SESSION_COOKIE = "kaffa_session";
const MAX_AGE = 60 * 60 * 8; // 8 hours

function secret(): string {
  return process.env.SESSION_SECRET || "dev-secret";
}

function sign(payload: string): string {
  return createHmac("sha256", secret()).update(payload).digest("hex");
}

export function makeToken(userId: string, role: string): string {
  const payload = userId + "|" + role + "|" + Date.now().toString();
  return payload + "|" + sign(payload);
}

export function verifyToken(token: string | undefined): {
  userId: string;
  role: string;
} | null {
  if (!token) return null;
  const parts = token.split("|");
  if (parts.length !== 4) return null;
  const [userId, role, issued, sig] = parts;
  const expected = sign(userId + "|" + role + "|" + issued);
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  const age = (Date.now() - Number(issued)) / 1000;
  if (!Number.isFinite(age) || age < 0 || age >= MAX_AGE) return null;
  return { userId, role };
}

// scrypt password hashing: salt is stored with the hash.
export function hashPassword(password: string): string {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(password, salt, 64).toString("hex");
  return salt + ":" + hash;
}

export function verifyPassword(password: string, stored: string): boolean {
  const [salt, hash] = stored.split(":");
  if (!salt || !hash) return false;
  const candidate = scryptSync(password, salt, 64);
  const expected = Buffer.from(hash, "hex");
  if (candidate.length !== expected.length) return false;
  return timingSafeEqual(candidate, expected);
}

export async function getSession(): Promise<{
  userId: string;
  role: string;
} | null> {
  const store = cookies();
  return verifyToken(store.get(SESSION_COOKIE)?.value);
}

export const sessionCookie = SESSION_COOKIE;
export const sessionMaxAge = MAX_AGE;

// Simple in-memory login rate limiter (5 failures per 15 minutes).
const attempts = new Map<string, { count: number; first: number }>();
const WINDOW_MS = 15 * 60 * 1000;

export function loginBlocked(key: string): boolean {
  const rec = attempts.get(key);
  if (!rec) return false;
  if (Date.now() - rec.first > WINDOW_MS) {
    attempts.delete(key);
    return false;
  }
  return rec.count >= 5;
}

export function recordFailedLogin(key: string): void {
  const now = Date.now();
  const rec = attempts.get(key);
  if (!rec || now - rec.first > WINDOW_MS) {
    attempts.set(key, { count: 1, first: now });
  } else {
    rec.count += 1;
  }
}

export function clearLoginAttempts(key: string): void {
  attempts.delete(key);
}
