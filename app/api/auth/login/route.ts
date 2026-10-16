import { NextResponse } from "next/server";
import { prisma } from "../../../../lib/prisma";
import {
  verifyPassword,
  makeToken,
  sessionCookie,
  sessionMaxAge,
  loginBlocked,
  recordFailedLogin,
  clearLoginAttempts
} from "../../../../lib/auth";

// Turns a raw server error into a readable JSON message. In most cases
// when this fires the SQLite database has not been created yet:
// run `npx prisma db push` and `npm run db:seed`.
function serverError(err: unknown): NextResponse {
  const msg = err instanceof Error ? err.message : String(err);
  console.error("login route error:", msg);
  const hint = /did not initialize|generate|database file|does not exist|P1001|P1003|P2003/i.test(msg)
    ? " The database may not be initialized. Run: npx prisma db push && npm run db:seed"
    : "";
  return NextResponse.json(
    { ok: false, error: "Server error: " + msg + "." + hint },
    { status: 500 }
  );
}

export async function POST(req: Request) {
  try {
    let body: { email?: unknown; password?: unknown };
    try {
      body = await req.json();
    } catch {
      return NextResponse.json({ ok: false, error: "Invalid request body." }, { status: 400 });
    }

    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");
    const key = "login:" + (email || "unknown");

    if (loginBlocked(key)) {
      return NextResponse.json(
        { ok: false, error: "Too many failed attempts. Try again in 15 minutes." },
        { status: 429 }
      );
    }

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || !verifyPassword(password, user.passwordHash)) {
      recordFailedLogin(key);
      return NextResponse.json({ ok: false, error: "Wrong email or password." }, { status: 401 });
    }

    clearLoginAttempts(key);
    const res = NextResponse.json({ ok: true, role: user.role });
    res.cookies.set(sessionCookie, makeToken(user.id, user.role), {
      httpOnly: true,
      sameSite: "lax",
      path: "/",
      maxAge: sessionMaxAge
    });
    return res;
  } catch (err) {
    return serverError(err);
  }
}
