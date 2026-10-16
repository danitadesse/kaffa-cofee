// Client-safe cart storage. Only slugs, quantities and price types are
// stored - every price shown to the user is recomputed by the server.

export const CART_KEY = "kaffa-cart";

export type CartItem = { slug: string; qty: number; priceType: string };

export function getCart(): CartItem[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(CART_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (i) => i && typeof i.slug === "string" && Number(i.qty) > 0
    );
  } catch {
    return [];
  }
}

export function saveCart(items: CartItem[]): void {
  window.localStorage.setItem(CART_KEY, JSON.stringify(items));
  window.dispatchEvent(new Event("kaffa-cart-changed"));
}

export function addToCart(slug: string, qty: number, priceType: string): void {
  const items = getCart();
  const existing = items.find((i) => i.slug === slug && i.priceType === priceType);
  if (existing) {
    existing.qty += Math.max(1, Math.floor(qty));
  } else {
    items.push({ slug, qty: Math.max(1, Math.floor(qty)), priceType });
  }
  saveCart(items);
}

export function updateQty(slug: string, priceType: string, qty: number): void {
  let items = getCart();
  if (qty <= 0) {
    items = items.filter((i) => !(i.slug === slug && i.priceType === priceType));
  } else {
    const it = items.find((i) => i.slug === slug && i.priceType === priceType);
    if (it) it.qty = Math.floor(qty);
  }
  saveCart(items);
}

export function clearCart(): void {
  window.localStorage.removeItem(CART_KEY);
  window.dispatchEvent(new Event("kaffa-cart-changed"));
}
