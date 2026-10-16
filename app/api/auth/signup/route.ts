import { NextResponse } from "next/server";
import { prisma } from "../../../../lib/prisma";
import { hashPassword, makeToken, sessionCookie, sessionMaxAge } from "../../../../lib/auth";

function serverError(err: unknown): NextResponse {
  const msg = err instanceof Error ? err.message : String(err);
  console.error("signup route error:", msg);
  const hint = /did not initialize|generate|database file|does not exist|P1001|P1003|P2002/i.test(msg)
    ? " The database may not be initialized. Run: npx prisma db push && npm run db:seed"
    : "";
  return NextResponse.json(
    { ok: false, error: "Server error: " + msg + "." + hint },
    { status: 500 }
  );
}

export async function POST(req: Request) {
  try {
    let body: { name?: unknown; email?: unknown; password?: unknown };
    try {
      body = await req.json();
    } catch {
      return NextResponse.json({ ok: false, error: "Invalid request body." }, { status: 400 });
    }

    const name = String(body.name || "").trim();
    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");

    if (name.length < 2 || name.length > 80) {
      return NextResponse.json({ ok: false, error: "Enter a valid full name." }, { status: 400 });
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return NextResponse.json({ ok: false, error: "Enter a valid email address." }, { status: 400 });
    }
    if (password.length < 8 || password.length > 100) {
      return NextResponse.json({ ok: false, error: "Password must be 8 to 100 characters." }, { status: 400 });
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      return NextResponse.json(
        { ok: false, error: "An account with this email already exists." },
        { status: 409 }
      );
    }

    const user = await prisma.user.create({
      data: { name, email, passwordHash: hashPassword(password), role: "customer" }
    });

    const res = NextResponse.json({ ok: true });
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
