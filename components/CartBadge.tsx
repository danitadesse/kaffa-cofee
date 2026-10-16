"use client";

import { useEffect, useState } from "react";
import { getCart } from "../lib/cart";

// Live cart count badge. Recomputed from localStorage on every
// "kaffa-cart-changed" event so all open tabs stay in sync.
export default function CartBadge() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    function refresh() {
      setCount(getCart().reduce((sum, i) => sum + i.qty, 0));
    }
    refresh();
    window.addEventListener("kaffa-cart-changed", refresh);
    window.addEventListener("storage", refresh);
    return () => {
      window.removeEventListener("kaffa-cart-changed", refresh);
      window.removeEventListener("storage", refresh);
    };
  }, []);

  return (
    <a href="/cart" className="cart-btn" aria-label="View cart">
      Cart
      {count > 0 ? <span className="cart-count">{count}</span> : null}
    </a>
  );
}
