import { NextResponse } from "next/server";
import { getSession, sessionCookie } from "../../../../lib/auth";

// GET is used by the header sign-out link: clears the session and
// redirects home. POST behaves the same but returns JSON.
export async function GET() {
  const res = NextResponse.redirect(new URL("/", process.env.NEXT_PUBLIC_BASE_URL || "http://localhost:3000"));
  res.cookies.set(sessionCookie, "", { httpOnly: true, sameSite: "lax", path: "/", maxAge: 0 });
  return res;
}

export async function POST() {
  await getSession(); // touch the auth module; cookie cleared below either way
  const res = NextResponse.json({ ok: true });
  res.cookies.set(sessionCookie, "", { httpOnly: true, sameSite: "lax", path: "/", maxAge: 0 });
  return res;
}
