"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

type Row = {
  slug: string;
  name: string;
  origin: string;
  process: string;
  roast: string;
  description: string;
  tastingNotes: string;
  hue: number;
  featured: boolean;
  active: boolean;
  retailPriceCents: number;
  retailStock: number;
  wholesaleEligible: boolean;
  wholesalePriceCents: number;
  wholesaleStock: number;
};

// Number fields are free-text strings while typing so they can be fully
// cleared; values are normalized on blur and validated on submit.
function NumField(props: {
  id: string;
  label: string;
  value: string;
  onChange: (v: string) => void;
  onBlur: () => void;
  step?: string;
}) {
  return (
    <div>
      <label htmlFor={props.id}>{props.label}</label>
      <input
        id={props.id}
        className="mono"
        type="number"
        step={props.step || "1"}
        value={props.value}
        onChange={(e) => props.onChange(e.target.value)}
        onBlur={props.onBlur}
      />
    </div>
  );
}

function normalize(text: string, fallback: string): string {
  const n = Number(text);
  if (!Number.isFinite(n)) return fallback;
  return String(n);
}

export default function ProductEditForm({ products }: { products: Row[] }) {
  const router = useRouter();
  const emptyDraft = {
    slug: "",
    name: "",
    origin: "",
    process: "Washed",
    roast: "Medium",
    description: "",
    tastingNotes: "",
    hue: "24",
    featured: false,
    active: true,
    retailPrice: "350",
    retailStock: "0",
    wholesaleEligible: false,
    wholesalePrice: "0",
    wholesaleStock: "0"
  };
  const [mode, setMode] = useState<"edit" | "create">("edit");
  const [slug, setSlug] = useState(products[0]?.slug || "");
  const [draft, setDraft] = useState(emptyDraft);
  const [retailPrice, setRetailPrice] = useState(((products[0]?.retailPriceCents || 0) / 100).toFixed(2));
  const [retailStock, setRetailStock] = useState(String(products[0]?.retailStock || 0));
  const [wholesalePrice, setWholesalePrice] = useState(((products[0]?.wholesalePriceCents || 0) / 100).toFixed(2));
  const [wholesaleStock, setWholesaleStock] = useState(String(products[0]?.wholesaleStock || 0));
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  function pick(nextSlug: string) {
    setMode("edit");
    setSlug(nextSlug);
    const p = products.find((x) => x.slug === nextSlug);
    if (p) {
      setRetailPrice((p.retailPriceCents / 100).toFixed(2));
      setRetailStock(String(p.retailStock));
      setWholesalePrice((p.wholesalePriceCents / 100).toFixed(2));
      setWholesaleStock(String(p.wholesaleStock));
    }
    setError(null);
    setDone(null);
  }

  function startCreate() {
    setMode("create");
    setDraft(emptyDraft);
    setError(null);
    setDone(null);
  }

  async function call(payload: Record<string, unknown>, okMsg: string) {
    setError(null);
    setDone(null);
    setBusy(true);
    try {
      const res = await fetch("/api/admin/products", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });
      const data = await res.json();
      if (res.ok && data.ok) {
        setDone(okMsg);
        router.refresh();
        return true;
      }
      setError(data.error || "Request failed.");
      return false;
    } catch {
      setError("Network error. Please try again.");
      return false;
    } finally {
      setBusy(false);
    }
  }

  async function submitEdit(e: React.FormEvent) {
    e.preventDefault();
    const ok = await call(
      {
        action: "update",
        slug,
        retailPrice,
        retailStock,
        wholesalePrice,
        wholesaleStock,
        active: products.find((p) => p.slug === slug)?.active
      },
      "Product updated."
    );
    if (ok) pick(slug);
  }

  async function toggleActive() {
    const p = products.find((x) => x.slug === slug);
    if (!p) return;
    await call(
      { action: "update", slug, active: !p.active },
      p.active ? "Product hidden from the shop." : "Product made visible in the shop."
    );
  }

  async function removeProduct() {
    const ok = await call({ action: "delete", slug }, "Product deleted.");
    if (ok) {
      const next = products.find((p) => p.slug !== slug);
      if (next) pick(next.slug);
    }
  }

  async function submitCreate(e: React.FormEvent) {
    e.preventDefault();
    const ok = await call({ action: "create", ...draft }, "Product created.");
    if (ok) {
      router.refresh();
      // After refresh the new product appears in the table; switch to editing it.
      setMode("edit");
      setSlug(draft.slug);
    }
  }

  if (products.length === 0 && mode === "edit") {
    return (
      <div>
        <p className="sub" style={{ marginBottom: 12 }}>No products yet. Create the first one.</p>
        <button type="button" className="btn" onClick={startCreate}>New product</button>
      </div>
    );
  }

  if (mode === "create") {
    return (
      <form className="form-stack" onSubmit={submitCreate}>
        <h3 style={{ fontSize: 14, marginTop: 0 }}>New product</h3>
        <div className="grid-2" style={{ gap: 12 }}>
          <div>
            <label htmlFor="n-slug">Slug (unique, lowercase, hyphens)</label>
            <input id="n-slug" value={draft.slug} onChange={(e) => setDraft({ ...draft, slug: e.target.value })} required />
          </div>
          <div>
            <label htmlFor="n-name">Name</label>
            <input id="n-name" value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} required />
          </div>
          <div>
            <label htmlFor="n-origin">Origin</label>
            <input id="n-origin" value={draft.origin} onChange={(e) => setDraft({ ...draft, origin: e.target.value })} required />
          </div>
          <div>
            <label htmlFor="n-process">Process</label>
            <input id="n-process" value={draft.process} onChange={(e) => setDraft({ ...draft, process: e.target.value })} required />
          </div>
          <div>
            <label htmlFor="n-roast">Roast</label>
            <input id="n-roast" value={draft.roast} onChange={(e) => setDraft({ ...draft, roast: e.target.value })} required />
          </div>
          <div>
            <label htmlFor="n-hue">Hue (0-359 for the card gradient)</label>
            <input id="n-hue" className="mono" type="number" min="0" max="359" value={draft.hue} onChange={(e) => setDraft({ ...draft, hue: e.target.value })} />
          </div>
          <div>
            <label htmlFor="n-rp">Retail price (ETB / 250g)</label>
            <input id="n-rp" className="mono" type="number" step="0.01" min="0" value={draft.retailPrice} onChange={(e) => setDraft({ ...draft, retailPrice: e.target.value })} required />
          </div>
          <div>
            <label htmlFor="n-rs">Retail stock</label>
            <input id="n-rs" className="mono" type="number" min="0" value={draft.retailStock} onChange={(e) => setDraft({ ...draft, retailStock: e.target.value })} />
          </div>
          <div>
            <label htmlFor="n-wp">Wholesale price (ETB / 60kg bag)</label>
            <input id="n-wp" className="mono" type="number" step="0.01" min="0" value={draft.wholesalePrice} onChange={(e) => setDraft({ ...draft, wholesalePrice: e.target.value })} />
          </div>
          <div>
            <label htmlFor="n-ws">Wholesale stock</label>
            <input id="n-ws" className="mono" type="number" min="0" value={draft.wholesaleStock} onChange={(e) => setDraft({ ...draft, wholesaleStock: e.target.value })} />
          </div>
        </div>
        <div>
          <label htmlFor="n-desc">Description</label>
          <input id="n-desc" className="wide-field" value={draft.description} onChange={(e) => setDraft({ ...draft, description: e.target.value })} required />
        </div>
        <div>
          <label htmlFor="n-notes">Tasting notes</label>
          <input id="n-notes" className="wide-field" value={draft.tastingNotes} onChange={(e) => setDraft({ ...draft, tastingNotes: e.target.value })} required />
        </div>
        <div style={{ display: "flex", gap: 20, flexWrap: "wrap" }}>
          <label>
            <input type="checkbox" checked={draft.wholesaleEligible} onChange={(e) => setDraft({ ...draft, wholesaleEligible: e.target.checked })} style={{ width: "auto", marginRight: 8 }} />
            Wholesale eligible
          </label>
          <label>
            <input type="checkbox" checked={draft.featured} onChange={(e) => setDraft({ ...draft, featured: e.target.checked })} style={{ width: "auto", marginRight: 8 }} />
            Featured on home page
          </label>
          <label>
            <input type="checkbox" checked={draft.active} onChange={(e) => setDraft({ ...draft, active: e.target.checked })} style={{ width: "auto", marginRight: 8 }} />
            Active
          </label>
        </div>
        {error ? <p className="error-text">{error}</p> : null}
        {done ? <p className="notice ok">{done}</p> : null}
        <div style={{ display: "flex", gap: 10 }}>
          <button type="submit" className="btn" disabled={busy}>{busy ? "Creating..." : "Create product"}</button>
          <button type="button" className="btn ghost" onClick={() => setMode("edit")}>Cancel</button>
        </div>
      </form>
    );
  }

  const selected = products.find((p) => p.slug === slug) || products[0];

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 10 }}>
        <h3 style={{ fontSize: 14, margin: 0 }}>Update a product</h3>
        <button type="button" className="btn sm" onClick={startCreate}>New product</button>
      </div>
      <form className="form-stack" onSubmit={submitEdit}>
        <div>
          <label htmlFor="prod">Product</label>
          <select id="prod" value={slug} onChange={(e) => pick(e.target.value)}>
            {products.map((p) => (
              <option key={p.slug} value={p.slug}>{p.name}</option>
            ))}
          </select>
        </div>
        <div className="grid-2" style={{ gap: 12 }}>
          <NumField id="rp" label="Retail price (ETB)" value={retailPrice} step="0.01"
            onChange={setRetailPrice} onBlur={() => setRetailPrice(normalize(retailPrice, retailPrice))} />
          <NumField id="rs" label="Retail stock" value={retailStock}
            onChange={setRetailStock} onBlur={() => setRetailStock(normalize(retailStock, retailStock))} />
          <NumField id="wp" label="Wholesale price (ETB / bag)" value={wholesalePrice} step="0.01"
            onChange={setWholesalePrice} onBlur={() => setWholesalePrice(normalize(wholesalePrice, wholesalePrice))} />
          <NumField id="ws" label="Wholesale stock" value={wholesaleStock}
            onChange={setWholesaleStock} onBlur={() => setWholesaleStock(normalize(wholesaleStock, wholesaleStock))} />
        </div>
        {error ? <p className="error-text">{error}</p> : null}
        {done ? <p className="notice ok">{done}</p> : null}
        <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
          <button type="submit" className="btn" disabled={busy}>{busy ? "Saving..." : "Save stock and prices"}</button>
          <button type="button" className="btn ghost" onClick={toggleActive} disabled={busy}>
            {selected?.active ? "Hide from shop" : "Show in shop"}
          </button>
          <button type="button" className="btn danger" onClick={removeProduct} disabled={busy}>
            Delete product
          </button>
        </div>
      </form>
    </div>
  );
}
