"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { getCart, clearCart, CartItem } from "../../lib/cart";
import { etb } from "../../lib/money";

type Priced = {
  ok: boolean;
  error?: string;
  subtotalCents: number;
  shippingCents: number;
  totalCents: number;
  items: { productName: string; qty: number; lineTotalCents: number; priceType: string }[];
};

export default function CheckoutForm({ defaultName }: { defaultName: string }) {
  const router = useRouter();
  const [name, setName] = useState(defaultName);
  const [phone, setPhone] = useState("");
  const [city, setCity] = useState("");
  const [addressLine, setAddressLine] = useState("");
  const [priced, setPriced] = useState<Priced | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const items = getCart();
    if (items.length === 0) return;
    const buyerType = items.some((i: CartItem) => i.priceType === "wholesale") ? "wholesale" : "retail";
    fetch("/api/cart", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ items, buyerType })
    })
      .then((r) => r.json())
      .then((d: Priced) => setPriced(d.ok ? d : null))
      .catch(() => setPriced(null));
  }, []);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const items = getCart();
    if (items.length === 0) {
      setError("Your cart is empty.");
      return;
    }
    setBusy(true);
    try {
      const res = await fetch("/api/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          items,
          buyerType: items.some((i: CartItem) => i.priceType === "wholesale") ? "wholesale" : "retail",
          name,
          phone,
          city,
          addressLine
        })
      });
      const data = await res.json();
      if (res.ok && data.ok) {
        clearCart();
        router.push("/orders/" + data.orderNo);
        return;
      }
      setError(data.error || "Could not place your order.");
    } catch {
      setError("Network error. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  const cart = getCart();
  if (cart.length === 0) {
    return (
      <div className="panel">
        <div className="panel-body">
          <p className="empty">Your cart is empty. <Link href="/shop">Go to the shop</Link>.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="grid-2" style={{ alignItems: "start" }}>
      <form className="panel" onSubmit={submit}>
        <div className="panel-head"><h2>Delivery details</h2></div>
        <div className="panel-body form-stack">
          <div>
            <label htmlFor="name">Full name</label>
            <input id="name" value={name} onChange={(e) => setName(e.target.value)} required maxLength={80} />
          </div>
          <div>
            <label htmlFor="phone">Phone</label>
            <input id="phone" className="mono" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+251 91 234 5678" required />
          </div>
          <div>
            <label htmlFor="city">City</label>
            <input id="city" value={city} onChange={(e) => setCity(e.target.value)} placeholder="Addis Ababa" required maxLength={60} />
          </div>
          <div>
            <label htmlFor="address">Street address</label>
            <input id="address" className="wide-field" value={addressLine} onChange={(e) => setAddressLine(e.target.value)} placeholder="Bole Road, Edna Mall Building, 3rd floor" required maxLength={160} />
          </div>
          {error ? <p className="error-text">{error}</p> : null}
          <button type="submit" className="btn wide" disabled={busy}>
            {busy ? "Placing order..." : "Place order"}
          </button>
        </div>
      </form>
      <div className="panel">
        <div className="panel-head"><h2>Order summary</h2></div>
        <div className="panel-body">
          {priced ? (
            <>
              {priced.items.map((i, idx) => (
                <p key={idx} className="sub" style={{ display: "flex", justifyContent: "space-between" }}>
                  <span>{i.productName} x {i.qty}</span>
                  <span className="mono">{etb(i.lineTotalCents)}</span>
                </p>
              ))}
              <p className="sub" style={{ display: "flex", justifyContent: "space-between" }}>
                <span>Shipping</span><span className="mono">{etb(priced.shippingCents)}</span>
              </p>
              <p style={{ display: "flex", justifyContent: "space-between", fontWeight: 700, marginTop: 12 }}>
                <span>Total</span><span className="mono">{etb(priced.totalCents)}</span>
              </p>
            </>
          ) : (
            <p className="sub">Loading totals...</p>
          )}
        </div>
      </div>
    </div>
  );
}
