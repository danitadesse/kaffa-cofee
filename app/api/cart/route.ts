import { NextResponse } from "next/server";
import { priceCart } from "../../../lib/prices";

// Recomputes cart prices from the database. Never trusts client prices.
export async function POST(req: Request) {
  let body: { items?: unknown; buyerType?: unknown };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid request body." }, { status: 400 });
  }
  const raw = Array.isArray(body.items) ? body.items : [];
  const buyerType = body.buyerType === "wholesale" ? "wholesale" : "retail";
  try {
    const priced = await priceCart(raw, buyerType);
    return NextResponse.json(priced, { status: priced.ok ? 200 : 400 });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("cart route error:", msg);
    return NextResponse.json({ ok: false, error: "Server error: " + msg + "." }, { status: 500 });
  }
}
