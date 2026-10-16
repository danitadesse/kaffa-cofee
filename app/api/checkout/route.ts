import { NextResponse } from "next/server";
import { prisma } from "../../../lib/prisma";
import { getSession } from "../../../lib/auth";
import { priceCart } from "../../../lib/prices";

function orderNo(): string {
  let out = "KO-";
  for (let i = 0; i < 6; i++) {
    out += "ABCDEFGHJKMNPQRSTUVWXYZ23456789"[Math.floor(Math.random() * 31)];
  }
  return out;
}

export async function POST(req: Request) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ ok: false, error: "Please sign in to check out." }, { status: 401 });
  }

  let body: {
    items?: unknown;
    buyerType?: unknown;
    name?: unknown;
    phone?: unknown;
    city?: unknown;
    addressLine?: unknown;
  };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid request body." }, { status: 400 });
  }

  const name = String(body.name || "").trim();
  const phone = String(body.phone || "").trim();
  const city = String(body.city || "").trim();
  const addressLine = String(body.addressLine || "").trim();
  const buyerType = body.buyerType === "wholesale" ? "wholesale" : "retail";

  if (name.length < 2 || name.length > 80) {
    return NextResponse.json({ ok: false, error: "Enter a valid full name." }, { status: 400 });
  }
  if (!/^\+?[0-9][0-9\s-]{6,14}$/.test(phone)) {
    return NextResponse.json({ ok: false, error: "Enter a valid phone number." }, { status: 400 });
  }
  if (city.length < 2 || city.length > 60) {
    return NextResponse.json({ ok: false, error: "Enter a valid city." }, { status: 400 });
  }
  if (addressLine.length < 5 || addressLine.length > 160) {
    return NextResponse.json({ ok: false, error: "Enter a valid street address." }, { status: 400 });
  }

  const raw = Array.isArray(body.items) ? body.items : [];
  let priced;
  try {
    priced = await priceCart(raw, buyerType);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("checkout pricing error:", msg);
    return NextResponse.json({ ok: false, error: "Server error: " + msg + "." }, { status: 500 });
  }
  if (!priced.ok) {
    return NextResponse.json({ ok: false, error: priced.error || "Your cart could not be priced." }, { status: 400 });
  }
  if (priced.items.some((i) => i.stockShort !== null && i.stockShort > 0)) {
    return NextResponse.json(
      { ok: false, error: "Some items exceed available stock. Adjust your cart and try again." },
      { status: 400 }
    );
  }

  const user = await prisma.user.findUnique({ where: { id: session.userId } });
  if (!user) {
    return NextResponse.json({ ok: false, error: "Account not found." }, { status: 401 });
  }

  try {
    const created = await prisma.$transaction(async (tx) => {
      const productIds = new Map<string, string>();
      // Re-check and decrement stock atomically for every line.
      for (const line of priced.items) {
        const product = await tx.product.findUnique({ where: { slug: line.slug } });
        if (!product || !product.active) {
          throw new Error("A product is no longer available: " + (product ? product.name : line.slug));
        }
        productIds.set(line.slug, product.id);
        if (line.priceType === "wholesale") {
          if (!product.wholesaleEligible) throw new Error("Not available wholesale.");
          if (product.wholesaleStock < line.qty) throw new Error("Insufficient wholesale stock for " + product.name + ".");
          await tx.product.update({
            where: { id: product.id },
            data: { wholesaleStock: { decrement: line.qty } }
          });
        } else {
          if (product.retailStock < line.qty) throw new Error("Insufficient stock for " + product.name + ".");
          await tx.product.update({
            where: { id: product.id },
            data: { retailStock: { decrement: line.qty } }
          });
        }
      }

      let no = orderNo();
      // Extremely unlikely, but keep order numbers unique.
      while (await tx.order.findUnique({ where: { orderNo: no } })) {
        no = orderNo();
      }

      const order = await tx.order.create({
        data: {
          orderNo: no,
          userId: user.id,
          buyerType,
          status: "placed",
          name,
          email: user.email,
          phone,
          city,
          addressLine,
          subtotalCents: priced.subtotalCents,
          shippingCents: priced.shippingCents,
          totalCents: priced.totalCents,
          items: {
            create: priced.items.map((i) => ({
              productId: productIds.get(i.slug) as string,
              productName: i.productName,
              priceType: i.priceType,
              unitPriceCents: i.unitPriceCents,
              qty: i.qty,
              lineTotalCents: i.lineTotalCents
            }))
          },
          events: {
            create: {
              status: "placed",
              message: "We received your order and sent this confirmation."
            }
          }
        }
      });
      return order;
    }, { timeout: 15000 });

    return NextResponse.json({ ok: true, orderNo: created.orderNo });
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Could not place your order.";
    return NextResponse.json({ ok: false, error: msg }, { status: 400 });
  }
}
