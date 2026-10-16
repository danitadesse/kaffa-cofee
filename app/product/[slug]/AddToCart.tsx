"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { addToCart } from "../../../lib/cart";
import { WHOLESALE_MOQ } from "../../../lib/money";

type Props = {
  slug: string;
  priceType: string;
  stock: number;
};

export default function AddToCart({ slug, priceType, stock }: Props) {
  const router = useRouter();
  // Qty is kept as a free-text string so the field can be fully cleared
  // while typing; it is normalized on blur and validated on submit.
  const [qtyText, setQtyText] = useState(priceType === "wholesale" ? String(WHOLESALE_MOQ) : "1");
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const wholesale = priceType === "wholesale";

  function normalize(text: string): string {
    const n = Math.floor(Number(text));
    if (!Number.isFinite(n) || n < 1) return "1";
    return String(n);
  }

  function onBlur() {
    setQtyText(normalize(qtyText));
  }

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    const qty = Math.floor(Number(qtyText));
    if (!Number.isFinite(qty) || qty < 1) {
      setError("Enter a quantity of at least 1.");
      return;
    }
    if (wholesale && qty < WHOLESALE_MOQ) {
      setError("Wholesale lots need at least " + WHOLESALE_MOQ + " bags per line.");
      return;
    }
    if (qty > stock) {
      setError("Only " + stock + " available in stock.");
      return;
    }
    addToCart(slug, qty, priceType);
    setDone(true);
    router.refresh();
  }

  return (
    <form onSubmit={submit} className="form-stack">
      <div>
        <label htmlFor="qty">Quantity ({wholesale ? "60kg bags" : "250g bags"})</label>
        <input
          id="qty"
          className="mono"
          type="number"
          min={1}
          max={stock}
          value={qtyText}
          onChange={(e) => {
            setQtyText(e.target.value);
            setDone(false);
          }}
          onBlur={onBlur}
          disabled={stock === 0}
        />
      </div>
      {error ? <p className="error-text">{error}</p> : null}
      {done ? <p className="notice ok">Added to cart.</p> : null}
      <div>
        <button type="submit" className="btn" disabled={stock === 0}>
          {stock === 0 ? "Out of stock" : "Add to cart"}
        </button>
      </div>
    </form>
  );
}
