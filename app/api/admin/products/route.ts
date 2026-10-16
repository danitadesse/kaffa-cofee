import { NextResponse } from "next/server";
import { prisma } from "../../../../lib/prisma";
import { getSession } from "../../../../lib/auth";
import { toCents } from "../../../../lib/money";

function forbidden() {
  return NextResponse.json({ ok: false, error: "Admin access required." }, { status: 403 });
}

function parseCents(v: unknown, label: string): number | null {
  const cents = toCents(v as string | number);
  if (cents === null || cents < 0 || cents > 100000000) return null;
  void label;
  return cents;
}

function parseStock(v: unknown): number | null {
  const stock = Math.floor(Number(v));
  if (!Number.isFinite(stock) || stock < 0 || stock > 100000) return null;
  return stock;
}

// Admin-only product CRUD: create, update (prices/stock/active/all fields)
// and delete. Prices arrive as ETB amounts and become integer cents.
export async function POST(req: Request) {
  const session = await getSession();
  if (!session || session.role !== "admin") return forbidden();

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid request body." }, { status: 400 });
  }

  const action = String(body.action || "update");

  // ---------- DELETE ----------
  if (action === "delete") {
    const slug = String(body.slug || "");
    const product = await prisma.product.findUnique({
      where: { slug },
      include: { orderItems: { select: { id: true } } }
    });
    if (!product) {
      return NextResponse.json({ ok: false, error: "Product not found." }, { status: 404 });
    }
    if (product.orderItems.length > 0) {
      return NextResponse.json(
        { ok: false, error: "This product appears in existing orders and cannot be deleted. Hide it instead." },
        { status: 409 }
      );
    }
    await prisma.product.delete({ where: { slug } });
    return NextResponse.json({ ok: true });
  }

  // ---------- CREATE ----------
  if (action === "create") {
    const slug = String(body.slug || "").trim().toLowerCase().replace(/[^a-z0-9-]/g, "-");
    const name = String(body.name || "").trim();
    const origin = String(body.origin || "").trim();
    const process_ = String(body.process || "").trim();
    const roast = String(body.roast || "").trim();
    const description = String(body.description || "").trim();
    const tastingNotes = String(body.tastingNotes || "").trim();

    if (!/^[a-z0-9][a-z0-9-]{1,60}$/.test(slug)) {
      return NextResponse.json({ ok: false, error: "Slug must be 2-61 chars: lowercase letters, digits, hyphens." }, { status: 400 });
    }
    for (const [v, label] of [[name, "Name"], [origin, "Origin"], [process_, "Process"], [roast, "Roast"], [description, "Description"], [tastingNotes, "Tasting notes"]] as [string, string][]) {
      if (v.length < 2 || v.length > 200) {
        return NextResponse.json({ ok: false, error: label + " must be 2 to 200 characters." }, { status: 400 });
      }
    }

    const hue = Math.floor(Number(body.hue));
    if (!Number.isFinite(hue) || hue < 0 || hue > 359) {
      return NextResponse.json({ ok: false, error: "Hue must be 0 to 359." }, { status: 400 });
    }
    const retailPriceCents = parseCents(body.retailPrice, "retail price");
    const retailStock = parseStock(body.retailStock);
    const wholesalePriceCents = parseCents(body.wholesalePrice, "wholesale price");
    const wholesaleStock = parseStock(body.wholesaleStock);
    if (retailPriceCents === null || retailStock === null || wholesalePriceCents === null || wholesaleStock === null) {
      return NextResponse.json({ ok: false, error: "Prices and stock must be valid non-negative numbers." }, { status: 400 });
    }

    const existing = await prisma.product.findUnique({ where: { slug } });
    if (existing) {
      return NextResponse.json({ ok: false, error: "A product with this slug already exists." }, { status: 409 });
    }

    await prisma.product.create({
      data: {
        slug,
        name,
        origin,
        process: process_,
        roast,
        description,
        tastingNotes,
        hue,
        featured: Boolean(body.featured),
        active: body.active === undefined ? true : Boolean(body.active),
        retailPriceCents,
        retailStock,
        wholesaleEligible: Boolean(body.wholesaleEligible),
        wholesalePriceCents,
        wholesaleStock
      }
    });
    return NextResponse.json({ ok: true });
  }

  // ---------- UPDATE (stock, prices, visibility) ----------
  if (action === "update") {
    const slug = String(body.slug || "");
    const product = await prisma.product.findUnique({ where: { slug } });
    if (!product) {
      return NextResponse.json({ ok: false, error: "Product not found." }, { status: 404 });
    }

    const data: Record<string, number | boolean> = {};
    if (body.retailPrice !== undefined) {
      const cents = parseCents(body.retailPrice, "retail price");
      if (cents === null) return NextResponse.json({ ok: false, error: "Invalid retail price." }, { status: 400 });
      data.retailPriceCents = cents;
    }
    if (body.retailStock !== undefined) {
      const stock = parseStock(body.retailStock);
      if (stock === null) return NextResponse.json({ ok: false, error: "Invalid retail stock." }, { status: 400 });
      data.retailStock = stock;
    }
    if (body.wholesalePrice !== undefined) {
      const cents = parseCents(body.wholesalePrice, "wholesale price");
      if (cents === null) return NextResponse.json({ ok: false, error: "Invalid wholesale price." }, { status: 400 });
      data.wholesalePriceCents = cents;
    }
    if (body.wholesaleStock !== undefined) {
      const stock = parseStock(body.wholesaleStock);
      if (stock === null) return NextResponse.json({ ok: false, error: "Invalid wholesale stock." }, { status: 400 });
      data.wholesaleStock = stock;
    }
    if (body.active !== undefined) {
      data.active = Boolean(body.active);
    }
    if (body.featured !== undefined) {
      data.featured = Boolean(body.featured);
    }

    if (Object.keys(data).length === 0) {
      return NextResponse.json({ ok: false, error: "Nothing to update." }, { status: 400 });
    }

    await prisma.product.update({ where: { slug }, data });
    return NextResponse.json({ ok: true });
  }

  return NextResponse.json({ ok: false, error: "Unknown action." }, { status: 400 });
}
