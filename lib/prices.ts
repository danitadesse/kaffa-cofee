import { prisma } from "./prisma";
import { WHOLESALE_MOQ } from "./money";

export const RETAIL_SHIPPING_CENTS = 25000; // flat ETB 250.00
export const FREE_RETAIL_SHIPPING_CENTS = 150000; // free over ETB 1,500.00
export const WHOLESALE_SHIPPING_CENTS = 450000; // flat ETB 4,500.00 freight

export type PricedItem = {
  slug: string;
  qty: number;
  priceType: string;
  productName: string;
  unitPriceCents: number;
  lineTotalCents: number;
  stockShort: number | null;
};

export type PricedCart = {
  ok: boolean;
  error?: string;
  items: PricedItem[];
  subtotalCents: number;
  shippingCents: number;
  totalCents: number;
};

// Recomputes a cart from the database. Client-sent prices are ignored.
export async function priceCart(
  raw: { slug: string; qty: number; priceType: string }[],
  buyerType: string
): Promise<PricedCart> {
  const clean = raw
    .filter((i) => i.slug && Number(i.qty) > 0)
    .map((i) => ({
      slug: String(i.slug),
      qty: Math.floor(Number(i.qty)),
      priceType: i.priceType === "wholesale" ? "wholesale" : "retail"
    }));

  if (clean.length === 0) {
    return { ok: false, error: "Your cart is empty.", items: [], subtotalCents: 0, shippingCents: 0, totalCents: 0 };
  }

  const items: PricedItem[] = [];
  let subtotal = 0;
  let wholesaleUnits = 0;

  for (const line of clean) {
    const p = await prisma.product.findUnique({ where: { slug: line.slug } });
    if (!p || !p.active) {
      return { ok: false, error: "A product in your cart is no longer available.", items: [], subtotalCents: 0, shippingCents: 0, totalCents: 0 };
    }
    if (line.priceType === "wholesale") {
      if (!p.wholesaleEligible) {
        return { ok: false, error: p.name + " is not available wholesale.", items: [], subtotalCents: 0, shippingCents: 0, totalCents: 0 };
      }
      if (line.qty < WHOLESALE_MOQ) {
        return { ok: false, error: p.name + " needs at least " + WHOLESALE_MOQ + " bags per wholesale order.", items: [], subtotalCents: 0, shippingCents: 0, totalCents: 0 };
      }
      if (line.qty > p.wholesaleStock) {
        items.push({
          slug: p.slug, qty: line.qty, priceType: "wholesale",
          productName: p.name, unitPriceCents: p.wholesalePriceCents,
          lineTotalCents: p.wholesalePriceCents * line.qty,
          stockShort: line.qty - p.wholesaleStock
        });
        subtotal += p.wholesalePriceCents * line.qty;
        wholesaleUnits += line.qty;
        continue;
      }
      const lineTotal = p.wholesalePriceCents * line.qty;
      items.push({ slug: p.slug, qty: line.qty, priceType: "wholesale", productName: p.name, unitPriceCents: p.wholesalePriceCents, lineTotalCents: lineTotal, stockShort: null });
      subtotal += lineTotal;
      wholesaleUnits += line.qty;
    } else {
      if (line.qty > p.retailStock) {
        items.push({
          slug: p.slug, qty: line.qty, priceType: "retail",
          productName: p.name, unitPriceCents: p.retailPriceCents,
          lineTotalCents: p.retailPriceCents * line.qty,
          stockShort: line.qty - p.retailStock
        });
        subtotal += p.retailPriceCents * line.qty;
        continue;
      }
      const lineTotal = p.retailPriceCents * line.qty;
      items.push({ slug: p.slug, qty: line.qty, priceType: "retail", productName: p.name, unitPriceCents: p.retailPriceCents, lineTotalCents: lineTotal, stockShort: null });
      subtotal += lineTotal;
    }
  }

  let shipping: number;
  if (buyerType === "wholesale" || wholesaleUnits > 0) {
    shipping = WHOLESALE_SHIPPING_CENTS;
  } else if (subtotal >= FREE_RETAIL_SHIPPING_CENTS) {
    shipping = 0;
  } else {
    shipping = RETAIL_SHIPPING_CENTS;
  }

  return {
    ok: true,
    items,
    subtotalCents: subtotal,
    shippingCents: shipping,
    totalCents: subtotal + shipping
  };
}
