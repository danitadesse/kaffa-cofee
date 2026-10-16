"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { getCart, updateQty, clearCart, CartItem } from "../../lib/cart";
import { etb } from "../../lib/money";

type PricedItem = {
  slug: string;
  qty: number;
  priceType: string;
  productName: string;
  unitPriceCents: number;
  lineTotalCents: number;
  stockShort: number | null;
};

type Priced = {
  ok: boolean;
  error?: string;
  items: PricedItem[];
  subtotalCents: number;
  shippingCents: number;
  totalCents: number;
};

const EMPTY: Priced = { ok: true, items: [], subtotalCents: 0, shippingCents: 0, totalCents: 0 };

export default function CartPage() {
  // mounted guard: the cart lives in localStorage, so all cart-derived
  // rendering happens after mount. This avoids server/client hydration
  // mismatches (server always sees an empty cart).
  const [mounted, setMounted] = useState(false);
  const [priced, setPriced] = useState<Priced>(EMPTY);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(true);
  // Qty inputs are free-text so the field can be cleared while typing.
  const [qtyTexts, setQtyTexts] = useState<Record<string, string>>({});

  const key = (slug: string, t: string) => slug + "|" + t;

  const reprice = useCallback(async () => {
    const items = getCart();
    setBusy(true);
    try {
      const res = await fetch("/api/cart", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          items,
          buyerType: items.some((i: CartItem) => i.priceType === "wholesale") ? "wholesale" : "retail"
        })
      });
      const data: Priced = await res.json();
      setPriced(data);
      setError(data.ok ? null : data.error || "Could not price your cart.");
    } catch {
      setError("Could not reach the server. Check that the dev server is running.");
    } finally {
      setBusy(false);
    }
  }, []);

  useEffect(() => {
    setMounted(true);
    const init = getCart().reduce<Record<string, string>>((acc, i) => {
      acc[key(i.slug, i.priceType)] = String(i.qty);
      return acc;
    }, {});
    setQtyTexts(init);
    reprice();
    const onChange = () => reprice();
    window.addEventListener("kaffa-cart-changed", onChange);
    return () => window.removeEventListener("kaffa-cart-changed", onChange);
  }, [reprice]);

  function setQty(slug: string, priceType: string, qty: number) {
    updateQty(slug, priceType, qty); // dispatches the change event, reprices
  }

  function onQtyInput(slug: string, priceType: string, text: string) {
    setQtyTexts((prev) => ({ ...prev, [key(slug, priceType)]: text }));
  }

  function onQtyBlur(slug: string, priceType: string) {
    const text = qtyTexts[key(slug, priceType)] || "";
    const n = Math.floor(Number(text));
    if (!Number.isFinite(n) || n < 1) {
      setQty(slug, priceType, 0); // remove the line
    } else {
      setQtyTexts((prev) => ({ ...prev, [key(slug, priceType)]: String(n) }));
      setQty(slug, priceType, n);
    }
  }

  function remove(slug: string, priceType: string) {
    setQty(slug, priceType, 0);
  }

  function wipe() {
    clearCart();
  }

  const cart = mounted ? getCart() : [];
  const hasShort = priced.items.some((i) => i.stockShort !== null && i.stockShort > 0);

  return (
    <div className="wrap section">
      <div className="page-head">
        <h1>Your cart</h1>
        {cart.length > 0 ? (
          <button type="button" className="btn ghost sm" onClick={wipe}>Clear cart</button>
        ) : null}
      </div>

      {error ? <p className="notice bad">{error}</p> : null}
      {hasShort ? (
        <p className="notice warn">
          Some lines exceed available stock. Reduce the quantity before checking out.
        </p>
      ) : null}

      {cart.length === 0 && !busy ? (
        <div className="panel">
          <div className="panel-body">
            <p className="empty">Your cart is empty. <Link href="/shop">Browse the shop</Link>.</p>
          </div>
        </div>
      ) : (
        <div className="grid-2" style={{ alignItems: "start" }}>
          <div className="panel">
            <div className="panel-head"><h2>Items</h2></div>
            <div className="table-scroll">
              <table className="ko-table">
                <thead>
                  <tr>
                    <th>Product</th>
                    <th>Type</th>
                    <th className="num">Unit</th>
                    <th className="num">Qty</th>
                    <th className="num">Line total</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {priced.items.map((i) => (
                    <tr key={key(i.slug, i.priceType)}>
                      <td>
                        {i.productName}
                        {i.stockShort ? (
                          <div className="error-text">Only {i.qty - i.stockShort} in stock</div>
                        ) : null}
                      </td>
                      <td>{i.priceType === "wholesale" ? "Wholesale 60kg" : "Retail 250g"}</td>
                      <td className="num">{etb(i.unitPriceCents)}</td>
                      <td className="num">
                        <input
                          className="mono"
                          type="number"
                          min={0}
                          value={qtyTexts[key(i.slug, i.priceType)] ?? String(i.qty)}
                          style={{ width: 70 }}
                          onChange={(e) => onQtyInput(i.slug, i.priceType, e.target.value)}
                          onBlur={() => onQtyBlur(i.slug, i.priceType)}
                        />
                      </td>
                      <td className="num">{etb(i.lineTotalCents)}</td>
                      <td className="num">
                        <button type="button" className="btn danger sm" onClick={() => remove(i.slug, i.priceType)}>
                          Remove
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
          <div className="panel">
            <div className="panel-head"><h2>Summary</h2></div>
            <div className="panel-body">
              <p className="sub" style={{ display: "flex", justifyContent: "space-between" }}>
                <span>Subtotal</span><span className="mono">{etb(priced.subtotalCents)}</span>
              </p>
              <p className="sub" style={{ display: "flex", justifyContent: "space-between" }}>
                <span>Shipping</span><span className="mono">{etb(priced.shippingCents)}</span>
              </p>
              <p style={{ display: "flex", justifyContent: "space-between", fontWeight: 700, marginTop: 14 }}>
                <span>Total</span><span className="mono">{etb(priced.totalCents)}</span>
              </p>
              <p style={{ marginTop: 20 }}>
                <Link href="/checkout" className={"btn wide" + (error || hasShort ? " disabled" : "")}>
                  {error || hasShort ? "Fix cart to continue" : "Proceed to checkout"}
                </Link>
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
