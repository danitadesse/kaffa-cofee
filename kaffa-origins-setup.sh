#!/usr/bin/env bash
# Kaffa Origins - full project setup script (v5)
# v5 UI/UX + admin batch:
#   - fixed cart-page hydration error (localStorage read now after mount)
#   - full-width layout on large screens
#   - number fields fully editable (can clear/remove the leading zero)
#   - light-mode ghost buttons on the dark chrome bar are now readable
#   - footer always sticks to the bottom (flex body layout)
#   - admin: full product CRUD (create/edit stock+prices/hide/delete)
#   - admin: advanced Users page (search, role filter, create, role
#     toggle, delete with order protection) at /admin/users
# v4: corrected AddToCart.tsx imports. v3: readable JSON API errors.
# v2: fixed relative import paths in nested route folders.
# Creates the complete Next.js 14 + Prisma + SQLite storefront in a folder
# named kaffa-origins. WARNING: run this in the PARENT folder - running it
# inside an existing kaffa-origins creates a nested kaffa-origins/kaffa-origins.
# Run:  bash kaffa-origins-setup.sh
set -e
mkdir -p kaffa-origins
cd kaffa-origins
cat > ".env.example" <<'KO_EOF'
# Sign-in secret for the session cookie (change to a long random string)
SESSION_SECRET=change-me-to-a-long-random-string
# SQLite database file
DATABASE_URL="file:./dev.db"
KO_EOF
cat > ".gitignore" <<'KO_EOF'
node_modules
.next
out
prisma/dev.db
prisma/*.db
.env
.DS_Store
*.tsbuildinfo
next-env.d.ts
KO_EOF
mkdir -p "app/admin"
cat > "app/admin/layout.tsx" <<'KO_EOF'
import { redirect } from "next/navigation";
import Link from "next/link";
import { getSession } from "../../lib/auth";

// Admin chrome with role guard. Non-admins never see admin data.
export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const session = await getSession();
  if (!session) redirect("/login?next=/admin");
  if (session.role !== "admin") redirect("/");

  return (
    <div className="wrap section">
      <div className="admin-bar">
        <h1 style={{ fontSize: 20 }}>Kaffa Origins admin</h1>
        <nav className="admin-nav">
          <Link href="/admin">Overview</Link>
          <Link href="/admin/orders">Orders</Link>
          <Link href="/admin/products">Products</Link>
          <Link href="/admin/users">Users</Link>
        </nav>
      </div>
      {children}
    </div>
  );
}
KO_EOF
mkdir -p "app/admin/orders/[orderNo]"
cat > "app/admin/orders/[orderNo]/page.tsx" <<'KO_EOF'
import Link from "next/link";
import { notFound } from "next/navigation";
import { prisma } from "../../../../lib/prisma";
import { etb } from "../../../../lib/money";
import { ORDER_STATUSES, ORDER_STATUS_LABELS, STATUS_CHIP_CLASS, STATUS_MESSAGES } from "../../../../lib/orderStatus";
import StatusForm from "./StatusForm";

export async function generateMetadata({ params }: { params: { orderNo: string } }) {
  return { title: "Order " + params.orderNo + " - admin" };
}

export default async function AdminOrderDetail({ params }: { params: { orderNo: string } }) {
  const order = await prisma.order.findUnique({
    where: { orderNo: params.orderNo },
    include: { items: true, events: { orderBy: { createdAt: "desc" } }, user: { select: { name: true, email: true } } }
  });
  if (!order) notFound();

  return (
    <>
      <p className="sub" style={{ marginBottom: 14 }}>
        <Link href="/admin/orders" className="sub">Orders</Link> / <span className="mono">{order.orderNo}</span>
      </p>
      <div className="page-head">
        <h2 style={{ margin: 0 }}>Order {order.orderNo}</h2>
        <span className={"chip " + (STATUS_CHIP_CLASS[order.status] || "neutral")}>
          {ORDER_STATUS_LABELS[order.status] || order.status}
        </span>
      </div>

      <div className="grid-2" style={{ alignItems: "start" }}>
        <div>
          <div className="panel" style={{ marginBottom: 18 }}>
            <div className="panel-head"><h2>Items</h2></div>
            <div className="table-scroll">
              <table className="ko-table">
                <thead>
                  <tr>
                    <th>Product</th>
                    <th>Type</th>
                    <th className="num">Unit</th>
                    <th className="num">Qty</th>
                    <th className="num">Total</th>
                  </tr>
                </thead>
                <tbody>
                  {order.items.map((i) => (
                    <tr key={i.id}>
                      <td>{i.productName}</td>
                      <td>{i.priceType}</td>
                      <td className="num">{etb(i.unitPriceCents)}</td>
                      <td className="num">{i.qty}</td>
                      <td className="num">{etb(i.lineTotalCents)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="pager">
              <span className="pager-info">
                Subtotal {etb(order.subtotalCents)} - Shipping {etb(order.shippingCents)}
              </span>
              <span className="pager-info" style={{ fontWeight: 700, color: "var(--ink)" }}>
                Total {etb(order.totalCents)}
              </span>
            </div>
          </div>
          <div className="panel">
            <div className="panel-head"><h2>Customer and delivery</h2></div>
            <div className="panel-body sub">
              {order.user.name} ({order.user.email})
              <br />
              {order.name} - {order.phone}
              <br />
              {order.addressLine}, {order.city}
            </div>
          </div>
        </div>
        <div>
          <div className="panel" style={{ marginBottom: 18 }}>
            <div className="panel-head"><h2>Update status</h2></div>
            <div className="panel-body">
              <StatusForm orderNo={order.orderNo} current={order.status} />
            </div>
          </div>
          <div className="panel">
            <div className="panel-head"><h2>History</h2></div>
            <div className="panel-body">
              <ul className="timeline">
                {order.events.map((e) => (
                  <li key={e.id}>
                    <div className="t-head">
                      <span className="t-title">{ORDER_STATUS_LABELS[e.status] || e.status}</span>
                      <span className="t-time">{e.createdAt.toISOString().replace("T", " ").slice(0, 16)}</span>
                    </div>
                    <p className="t-msg">{e.message || STATUS_MESSAGES[e.status]}</p>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
KO_EOF
mkdir -p "app/admin/orders/[orderNo]"
cat > "app/admin/orders/[orderNo]/StatusForm.tsx" <<'KO_EOF'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { ORDER_STATUSES, ORDER_STATUS_LABELS, STATUS_MESSAGES } from "../../../../lib/orderStatus";

export default function StatusForm({ orderNo, current }: { orderNo: string; current: string }) {
  const router = useRouter();
  const [status, setStatus] = useState(current);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const res = await fetch("/api/admin/orders", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ orderNo, status })
      });
      const data = await res.json();
      if (res.ok && data.ok) {
        router.refresh();
        return;
      }
      setError(data.error || "Could not update the order.");
    } catch {
      setError("Network error. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="form-stack" onSubmit={submit}>
      <div>
        <label htmlFor="status">New status</label>
        <select id="status" value={status} onChange={(e) => setStatus(e.target.value)}>
          {ORDER_STATUSES.map((s) => (
            <option key={s} value={s}>{ORDER_STATUS_LABELS[s]}</option>
          ))}
        </select>
      </div>
      <p className="sub">The customer will see: {STATUS_MESSAGES[status]}</p>
      {error ? <p className="error-text">{error}</p> : null}
      <button type="submit" className="btn" disabled={busy || status === current}>
        {busy ? "Saving..." : "Save status"}
      </button>
    </form>
  );
}
KO_EOF
mkdir -p "app/admin/orders"
cat > "app/admin/orders/page.tsx" <<'KO_EOF'
import Link from "next/link";
import { prisma } from "../../../lib/prisma";
import { etb } from "../../../lib/money";
import { ORDER_STATUSES, ORDER_STATUS_LABELS, STATUS_CHIP_CLASS, BUYER_TYPE_LABELS } from "../../../lib/orderStatus";
import Pager from "../../../components/Pager";

export const metadata = { title: "Orders - Kaffa Origins admin" };

const PER_PAGE = 10;

export default async function AdminOrdersPage({
  searchParams
}: {
  searchParams: { page?: string; status?: string };
}) {
  const status = ORDER_STATUSES.includes(String(searchParams.status)) ? String(searchParams.status) : undefined;
  const page = Math.max(1, Math.floor(Number(searchParams.page) || 1) || 1);

  const [total, orders] = await Promise.all([
    prisma.order.count(status ? { where: { status } } : undefined),
    prisma.order.findMany({
      where: status ? { status } : {},
      orderBy: { createdAt: "desc" },
      skip: (page - 1) * PER_PAGE,
      take: PER_PAGE,
      include: { items: true, user: { select: { name: true, email: true } } }
    })
  ]);

  return (
    <>
      <div className="mode-switch" style={{ marginBottom: 18 }}>
        <Link href="/admin/orders" className={!status ? "on" : ""}>All</Link>
        {ORDER_STATUSES.map((s) => (
          <Link key={s} href={"/admin/orders?status=" + s} className={status === s ? "on" : ""}>
            {ORDER_STATUS_LABELS[s]}
          </Link>
        ))}
      </div>
      <div className="panel">
        {orders.length === 0 ? (
          <p className="empty">No orders match this filter.</p>
        ) : (
          <>
            <div className="table-scroll">
              <table className="ko-table">
                <thead>
                  <tr>
                    <th>Order</th>
                    <th>Customer</th>
                    <th>Date</th>
                    <th>Type</th>
                    <th className="num">Total</th>
                    <th>Status</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {orders.map((o) => (
                    <tr key={o.id}>
                      <td className="mono">{o.orderNo}</td>
                      <td>{o.user.name}<div className="sub">{o.user.email}</div></td>
                      <td>{o.createdAt.toISOString().slice(0, 10)}</td>
                      <td>{BUYER_TYPE_LABELS[o.buyerType] || o.buyerType}</td>
                      <td className="num">{etb(o.totalCents)}</td>
                      <td>
                        <span className={"chip " + (STATUS_CHIP_CLASS[o.status] || "neutral")}>
                          {ORDER_STATUS_LABELS[o.status] || o.status}
                        </span>
                      </td>
                      <td>
                        <Link href={"/admin/orders/" + o.orderNo} className="btn ghost sm">Review</Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Pager
              page={page}
              total={total}
              perPage={PER_PAGE}
              basePath="/admin/orders"
              extraParams={status ? { status } : {}}
            />
          </>
        )}
      </div>
    </>
  );
}
KO_EOF
mkdir -p "app/admin"
cat > "app/admin/page.tsx" <<'KO_EOF'
import { prisma } from "../../lib/prisma";
import { etb } from "../../lib/money";
import { ORDER_STATUSES, ORDER_STATUS_LABELS } from "../../lib/orderStatus";
import Link from "next/link";

export const metadata = { title: "Admin overview - Kaffa Origins" };

export default async function AdminOverviewPage() {
  const [orders, products] = await Promise.all([
    prisma.order.findMany({ select: { status: true, totalCents: true, buyerType: true } }),
    prisma.product.findMany({
      where: { active: true },
      select: { name: true, retailStock: true, wholesaleStock: true }
    })
  ]);

  const revenue = orders
    .filter((o) => o.status !== "cancelled")
    .reduce((sum, o) => sum + o.totalCents, 0);
  const wholesaleOrders = orders.filter((o) => o.buyerType === "wholesale").length;
  const lowStock = products.filter(
    (p) => p.retailStock < 10 || p.wholesaleStock < 10
  );

  const byStatus: Record<string, number> = {};
  for (const o of orders) byStatus[o.status] = (byStatus[o.status] || 0) + 1;

  return (
    <>
      <div className="stat-grid">
        <div className="stat">
          <div className="l">Orders</div>
          <div className="n">{orders.length}</div>
        </div>
        <div className="stat">
          <div className="l">Revenue (excl. cancelled)</div>
          <div className="n">{etb(revenue)}</div>
        </div>
        <div className="stat">
          <div className="l">Wholesale orders</div>
          <div className="n">{wholesaleOrders}</div>
        </div>
      </div>

      <div className="grid-2" style={{ alignItems: "start" }}>
        <div className="panel">
          <div className="panel-head"><h2>Orders by status</h2></div>
          <div className="panel-body">
            {ORDER_STATUSES.map((s) => (
              <p key={s} className="sub" style={{ display: "flex", justifyContent: "space-between" }}>
                <span>{ORDER_STATUS_LABELS[s]}</span>
                <span className="mono">{byStatus[s] || 0}</span>
              </p>
            ))}
            <p style={{ marginTop: 12 }}>
              <Link href="/admin/orders" className="btn sm">Manage orders</Link>
            </p>
          </div>
        </div>
        <div className="panel">
          <div className="panel-head"><h2>Low stock (under 10)</h2></div>
          <div className="panel-body">
            {lowStock.length === 0 ? (
              <p className="empty">All active products are well stocked.</p>
            ) : (
              lowStock.map((p) => (
                <p key={p.name} className="sub" style={{ display: "flex", justifyContent: "space-between" }}>
                  <span>{p.name}</span>
                  <span className="mono">{p.retailStock} retail / {p.wholesaleStock} wholesale</span>
                </p>
              ))
            )}
            <p style={{ marginTop: 12 }}>
              <Link href="/admin/products" className="btn sm">Edit products</Link>
            </p>
          </div>
        </div>
      </div>
    </>
  );
}
KO_EOF
mkdir -p "app/admin/products"
cat > "app/admin/products/page.tsx" <<'KO_EOF'
import Link from "next/link";
import { prisma } from "../../../lib/prisma";
import { etb } from "../../../lib/money";
import Pager from "../../../components/Pager";
import ProductEditForm from "./ProductEditForm";

export const metadata = { title: "Products - Kaffa Origins admin" };

const PER_PAGE = 10;

export default async function AdminProductsPage({
  searchParams
}: {
  searchParams: { page?: string };
}) {
  const page = Math.max(1, Math.floor(Number(searchParams.page) || 1) || 1);
  const [total, products] = await Promise.all([
    prisma.product.count(),
    prisma.product.findMany({
      orderBy: { name: "asc" },
      skip: (page - 1) * PER_PAGE,
      take: PER_PAGE
    })
  ]);

  return (
    <div className="panel">
      <div className="panel-head">
        <h2>Catalog</h2>
        <span className="sub">Full CRUD below the table: create, edit stock and prices, hide or delete.</span>
      </div>
      {products.length === 0 ? (
        <p className="empty">No products. Create one below.</p>
      ) : (
        <>
          <div className="table-scroll">
            <table className="ko-table">
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Origin</th>
                  <th className="num">Retail price</th>
                  <th className="num">Retail stock</th>
                  <th className="num">Wholesale price</th>
                  <th className="num">Wholesale stock</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {products.map((p) => (
                  <tr key={p.id}>
                    <td>{p.name}<div className="sub">{p.slug}</div></td>
                    <td>{p.origin}</td>
                    <td className="num">{etb(p.retailPriceCents)}</td>
                    <td className="num">{p.retailStock}</td>
                    <td className="num">{p.wholesaleEligible ? etb(p.wholesalePriceCents) : "-"}</td>
                    <td className="num">{p.wholesaleEligible ? p.wholesaleStock : "-"}</td>
                    <td>
                      <span className={"chip " + (p.active ? "ok" : "bad")}>
                        {p.active ? "Active" : "Hidden"}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <Pager page={page} total={total} perPage={PER_PAGE} basePath="/admin/products" />
        </>
      )}
      <div className="panel-body">
        <ProductEditForm
          products={products.map((p) => ({
            slug: p.slug,
            name: p.name,
            origin: p.origin,
            process: p.process,
            roast: p.roast,
            description: p.description,
            tastingNotes: p.tastingNotes,
            hue: p.hue,
            featured: p.featured,
            active: p.active,
            retailPriceCents: p.retailPriceCents,
            retailStock: p.retailStock,
            wholesaleEligible: p.wholesaleEligible,
            wholesalePriceCents: p.wholesalePriceCents,
            wholesaleStock: p.wholesaleStock
          }))}
        />
      </div>
    </div>
  );
}
KO_EOF
mkdir -p "app/admin/products"
cat > "app/admin/products/ProductEditForm.tsx" <<'KO_EOF'
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
KO_EOF
mkdir -p "app/admin/users"
cat > "app/admin/users/page.tsx" <<'KO_EOF'
import { prisma } from "../../../lib/prisma";
import Pager from "../../../components/Pager";
import { etb } from "../../../lib/money";
import UserAdmin from "./UserAdmin";

export const metadata = { title: "Users - Kaffa Origins admin" };

const PER_PAGE = 10;

export default async function AdminUsersPage({
  searchParams
}: {
  searchParams: { page?: string; q?: string; role?: string };
}) {
  const q = String(searchParams.q || "").trim();
  const role = searchParams.role === "admin" || searchParams.role === "customer" ? searchParams.role : undefined;
  const page = Math.max(1, Math.floor(Number(searchParams.page) || 1) || 1);

  const where = {
    AND: [
      q
        ? {
            OR: [
              { name: { contains: q } },
              { email: { contains: q } }
            ]
          }
        : {},
      role ? { role } : {}
    ]
  };

  const [total, users] = await Promise.all([
    prisma.user.count({ where }),
    prisma.user.findMany({
      where,
      orderBy: { createdAt: "desc" },
      skip: (page - 1) * PER_PAGE,
      take: PER_PAGE,
      include: { orders: { select: { id: true, totalCents: true } } }
    })
  ]);

  const extra: Record<string, string> = {};
  if (q) extra.q = q;
  if (role) extra.role = role;

  return (
    <>
      <form className="panel" method="get" action="/admin/users">
        <div className="panel-body" style={{ display: "flex", gap: 10, flexWrap: "wrap", alignItems: "flex-end" }}>
          <div style={{ flex: "1 1 220px" }}>
            <label htmlFor="q">Search name or email</label>
            <input id="q" name="q" defaultValue={q} placeholder="daniel, sara, @kaffaorigins..." />
          </div>
          <div>
            <label htmlFor="role">Role</label>
            <select id="role" name="role" defaultValue={role || ""}>
              <option value="">All roles</option>
              <option value="customer">Customer</option>
              <option value="admin">Admin</option>
            </select>
          </div>
          <button type="submit" className="btn sm">Search</button>
        </div>
      </form>
      <div className="panel">
        <div className="panel-head">
          <h2>Users ({total})</h2>
        </div>
        {users.length === 0 ? (
          <p className="empty">No users match this filter.</p>
        ) : (
          <>
            <div className="table-scroll">
              <table className="ko-table">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Role</th>
                    <th className="num">Orders</th>
                    <th className="num">Lifetime value</th>
                    <th>Joined</th>
                  </tr>
                </thead>
                <tbody>
                  {users.map((u) => (
                    <tr key={u.id}>
                      <td>{u.name}</td>
                      <td className="mono">{u.email}</td>
                      <td>
                        <span className={"chip " + (u.role === "admin" ? "neutral" : "ok")}>{u.role}</span>
                      </td>
                      <td className="num">{u.orders.length}</td>
                      <td className="num">{etb(u.orders.reduce((s, o) => s + o.totalCents, 0))}</td>
                      <td>{u.createdAt.toISOString().slice(0, 10)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Pager page={page} total={total} perPage={PER_PAGE} basePath="/admin/users" extraParams={extra} />
          </>
        )}
        <div className="panel-body">
          <UserAdmin
            users={users.map((u) => ({
              id: u.id,
              name: u.name,
              email: u.email,
              role: u.role,
              orderCount: u.orders.length,
              isSelf: u.email === "admin@kaffaorigins.et"
            }))}
          />
        </div>
      </div>
    </>
  );
}
KO_EOF
mkdir -p "app/admin/users"
cat > "app/admin/users/UserAdmin.tsx" <<'KO_EOF'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

type Row = {
  id: string;
  name: string;
  email: string;
  role: string;
  orderCount: number;
  isSelf: boolean;
};

export default function UserAdmin({ users }: { users: Row[] }) {
  const router = useRouter();
  const [mode, setMode] = useState<"edit" | "create">("edit");
  const [id, setId] = useState(users[0]?.id || "");
  const [draft, setDraft] = useState({ name: "", email: "", password: "", role: "customer" });
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  function pick(nextId: string) {
    setMode("edit");
    setId(nextId);
    setError(null);
    setDone(null);
  }

  function startCreate() {
    setMode("create");
    setDraft({ name: "", email: "", password: "", role: "customer" });
    setError(null);
    setDone(null);
  }

  async function call(payload: Record<string, unknown>, okMsg: string) {
    setError(null);
    setDone(null);
    setBusy(true);
    try {
      const res = await fetch("/api/admin/users", {
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

  async function submitCreate(e: React.FormEvent) {
    e.preventDefault();
    const ok = await call({ action: "create", ...draft }, "User created.");
    if (ok) setMode("edit");
  }

  async function submitEdit(e: React.FormEvent) {
    e.preventDefault();
    const u = users.find((x) => x.id === id);
    if (!u) return;
    const ok = await call(
      { action: "update", userId: id, role: u.role === "admin" ? "customer" : "admin" },
      u.role === "admin" ? "Admin role removed." : "Admin role granted."
    );
    if (ok) pick(id);
  }

  async function removeUser() {
    const u = users.find((x) => x.id === id);
    if (!u) return;
    const ok = await call({ action: "delete", userId: id }, "User deleted.");
    if (ok) {
      const next = users.find((x) => x.id !== id);
      if (next) pick(next.id);
    }
  }

  if (users.length === 0 && mode === "edit") {
    return (
      <div>
        <p className="sub" style={{ marginBottom: 12 }}>No users match the filter. Create one anyway?</p>
        <button type="button" className="btn" onClick={startCreate}>New user</button>
      </div>
    );
  }

  if (mode === "create") {
    return (
      <form className="form-stack" onSubmit={submitCreate}>
        <h3 style={{ fontSize: 14, marginTop: 0 }}>New user</h3>
        <div className="grid-2" style={{ gap: 12 }}>
          <div>
            <label htmlFor="u-name">Full name</label>
            <input id="u-name" value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} required />
          </div>
          <div>
            <label htmlFor="u-email">Email</label>
            <input id="u-email" type="email" value={draft.email} onChange={(e) => setDraft({ ...draft, email: e.target.value })} required />
          </div>
          <div>
            <label htmlFor="u-pass">Password (min 8 characters)</label>
            <input id="u-pass" type="password" value={draft.password} onChange={(e) => setDraft({ ...draft, password: e.target.value })} required minLength={8} />
          </div>
          <div>
            <label htmlFor="u-role">Role</label>
            <select id="u-role" value={draft.role} onChange={(e) => setDraft({ ...draft, role: e.target.value })}>
              <option value="customer">Customer</option>
              <option value="admin">Admin</option>
            </select>
          </div>
        </div>
        {error ? <p className="error-text">{error}</p> : null}
        {done ? <p className="notice ok">{done}</p> : null}
        <div style={{ display: "flex", gap: 10 }}>
          <button type="submit" className="btn" disabled={busy}>{busy ? "Creating..." : "Create user"}</button>
          <button type="button" className="btn ghost" onClick={() => setMode("edit")}>Cancel</button>
        </div>
      </form>
    );
  }

  const selected = users.find((u) => u.id === id) || users[0];

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 10 }}>
        <h3 style={{ fontSize: 14, margin: 0 }}>Manage a user</h3>
        <button type="button" className="btn sm" onClick={startCreate}>New user</button>
      </div>
      <form className="form-stack" onSubmit={submitEdit}>
        <div>
          <label htmlFor="user">User</label>
          <select id="user" value={id} onChange={(e) => pick(e.target.value)}>
            {users.map((u) => (
              <option key={u.id} value={u.id}>{u.name} ({u.email})</option>
            ))}
          </select>
        </div>
        <p className="sub">
          Current role: <strong>{selected?.role}</strong> - {selected?.orderCount} order(s) on record.
          {selected?.isSelf ? " This is the primary admin account." : ""}
        </p>
        {error ? <p className="error-text">{error}</p> : null}
        {done ? <p className="notice ok">{done}</p> : null}
        <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
          <button type="submit" className="btn" disabled={busy || selected?.isSelf}>
            {selected?.role === "admin" ? "Make customer" : "Make admin"}
          </button>
          <button type="button" className="btn danger" onClick={removeUser} disabled={busy || selected?.isSelf}>
            Delete user
          </button>
        </div>
        {selected?.isSelf ? (
          <p className="sub" style={{ marginTop: 10 }}>
            The primary admin account cannot be demoted or deleted from here.
          </p>
        ) : null}
      </form>
    </div>
  );
}
KO_EOF
mkdir -p "app/api/admin/orders"
cat > "app/api/admin/orders/route.ts" <<'KO_EOF'
import { NextResponse } from "next/server";
import { prisma } from "../../../../lib/prisma";
import { getSession } from "../../../../lib/auth";
import { ORDER_STATUSES, STATUS_MESSAGES } from "../../../../lib/orderStatus";

// Admin-only: update order status and write an email-style OrderEvent
// the customer sees on their order timeline.
async function update(orderNo: string, status: string) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ ok: false, error: "Admin access required." }, { status: 403 });
  }
  if (!ORDER_STATUSES.includes(status)) {
    return NextResponse.json({ ok: false, error: "Unknown order status." }, { status: 400 });
  }

  const order = await prisma.order.findUnique({ where: { orderNo } });
  if (!order) {
    return NextResponse.json({ ok: false, error: "Order not found." }, { status: 404 });
  }
  if (order.status === status) {
    return NextResponse.json({ ok: true, message: "No change." });
  }

  await prisma.order.update({
    where: { orderNo },
    data: {
      status,
      events: { create: { status, message: STATUS_MESSAGES[status] } }
    }
  });

  return NextResponse.json({ ok: true });
}

export async function POST(req: Request) {
  let body: { orderNo?: unknown; status?: unknown };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid request body." }, { status: 400 });
  }
  return update(String(body.orderNo || ""), String(body.status || ""));
}

export async function GET(req: Request) {
  const url = new URL(req.url);
  return update(url.searchParams.get("orderNo") || "", url.searchParams.get("status") || "");
}
KO_EOF
mkdir -p "app/api/admin/products"
cat > "app/api/admin/products/route.ts" <<'KO_EOF'
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
KO_EOF
mkdir -p "app/api/admin/users"
cat > "app/api/admin/users/route.ts" <<'KO_EOF'
import { NextResponse } from "next/server";
import { prisma } from "../../../../lib/prisma";
import { getSession, hashPassword } from "../../../../lib/auth";

function forbidden() {
  return NextResponse.json({ ok: false, error: "Admin access required." }, { status: 403 });
}

// Admin-only user CRUD: create, update role, delete.
// The primary admin (admin@kaffaorigins.et) cannot be demoted or deleted.
// Users with orders cannot be deleted (order history must stay intact);
// their role can still be changed.
export async function POST(req: Request) {
  const session = await getSession();
  if (!session || session.role !== "admin") return forbidden();

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid request body." }, { status: 400 });
  }

  const action = String(body.action || "");

  // ---------- CREATE ----------
  if (action === "create") {
    const name = String(body.name || "").trim();
    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");
    const role = body.role === "admin" ? "admin" : "customer";

    if (name.length < 2 || name.length > 80) {
      return NextResponse.json({ ok: false, error: "Enter a valid full name." }, { status: 400 });
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return NextResponse.json({ ok: false, error: "Enter a valid email address." }, { status: 400 });
    }
    if (password.length < 8 || password.length > 100) {
      return NextResponse.json({ ok: false, error: "Password must be 8 to 100 characters." }, { status: 400 });
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      return NextResponse.json({ ok: false, error: "An account with this email already exists." }, { status: 409 });
    }

    await prisma.user.create({
      data: { name, email, passwordHash: hashPassword(password), role }
    });
    return NextResponse.json({ ok: true });
  }

  // ---------- UPDATE (role) ----------
  if (action === "update") {
    const userId = String(body.userId || "");
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return NextResponse.json({ ok: false, error: "User not found." }, { status: 404 });
    }
    if (user.email === "admin@kaffaorigins.et") {
      return NextResponse.json({ ok: false, error: "The primary admin account cannot be demoted." }, { status: 403 });
    }
    const role = user.role === "admin" ? "customer" : "admin";
    await prisma.user.update({ where: { id: userId }, data: { role } });
    return NextResponse.json({ ok: true, role });
  }

  // ---------- DELETE ----------
  if (action === "delete") {
    const userId = String(body.userId || "");
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: { orders: { select: { id: true } } }
    });
    if (!user) {
      return NextResponse.json({ ok: false, error: "User not found." }, { status: 404 });
    }
    if (user.email === "admin@kaffaorigins.et") {
      return NextResponse.json({ ok: false, error: "The primary admin account cannot be deleted." }, { status: 403 });
    }
    if (user.orders.length > 0) {
      return NextResponse.json(
        { ok: false, error: "This user has " + user.orders.length + " order(s) and cannot be deleted. You can still change their role." },
        { status: 409 }
      );
    }
    await prisma.user.delete({ where: { id: userId } });
    return NextResponse.json({ ok: true });
  }

  return NextResponse.json({ ok: false, error: "Unknown action." }, { status: 400 });
}
KO_EOF
mkdir -p "app/api/auth/login"
cat > "app/api/auth/login/route.ts" <<'KO_EOF'
import { NextResponse } from "next/server";
import { prisma } from "../../../../lib/prisma";
import {
  verifyPassword,
  makeToken,
  sessionCookie,
  sessionMaxAge,
  loginBlocked,
  recordFailedLogin,
  clearLoginAttempts
} from "../../../../lib/auth";

// Turns a raw server error into a readable JSON message. In most cases
// when this fires the SQLite database has not been created yet:
// run `npx prisma db push` and `npm run db:seed`.
function serverError(err: unknown): NextResponse {
  const msg = err instanceof Error ? err.message : String(err);
  console.error("login route error:", msg);
  const hint = /did not initialize|generate|database file|does not exist|P1001|P1003|P2003/i.test(msg)
    ? " The database may not be initialized. Run: npx prisma db push && npm run db:seed"
    : "";
  return NextResponse.json(
    { ok: false, error: "Server error: " + msg + "." + hint },
    { status: 500 }
  );
}

export async function POST(req: Request) {
  try {
    let body: { email?: unknown; password?: unknown };
    try {
      body = await req.json();
    } catch {
      return NextResponse.json({ ok: false, error: "Invalid request body." }, { status: 400 });
    }

    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");
    const key = "login:" + (email || "unknown");

    if (loginBlocked(key)) {
      return NextResponse.json(
        { ok: false, error: "Too many failed attempts. Try again in 15 minutes." },
        { status: 429 }
      );
    }

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || !verifyPassword(password, user.passwordHash)) {
      recordFailedLogin(key);
      return NextResponse.json({ ok: false, error: "Wrong email or password." }, { status: 401 });
    }

    clearLoginAttempts(key);
    const res = NextResponse.json({ ok: true, role: user.role });
    res.cookies.set(sessionCookie, makeToken(user.id, user.role), {
      httpOnly: true,
      sameSite: "lax",
      path: "/",
      maxAge: sessionMaxAge
    });
    return res;
  } catch (err) {
    return serverError(err);
  }
}
KO_EOF
mkdir -p "app/api/auth/logout"
cat > "app/api/auth/logout/route.ts" <<'KO_EOF'
import { NextResponse } from "next/server";
import { getSession, sessionCookie } from "../../../../lib/auth";

// GET is used by the header sign-out link: clears the session and
// redirects home. POST behaves the same but returns JSON.
export async function GET() {
  const res = NextResponse.redirect(new URL("/", process.env.NEXT_PUBLIC_BASE_URL || "http://localhost:3000"));
  res.cookies.set(sessionCookie, "", { httpOnly: true, sameSite: "lax", path: "/", maxAge: 0 });
  return res;
}

export async function POST() {
  await getSession(); // touch the auth module; cookie cleared below either way
  const res = NextResponse.json({ ok: true });
  res.cookies.set(sessionCookie, "", { httpOnly: true, sameSite: "lax", path: "/", maxAge: 0 });
  return res;
}
KO_EOF
mkdir -p "app/api/auth/signup"
cat > "app/api/auth/signup/route.ts" <<'KO_EOF'
import { NextResponse } from "next/server";
import { prisma } from "../../../../lib/prisma";
import { hashPassword, makeToken, sessionCookie, sessionMaxAge } from "../../../../lib/auth";

function serverError(err: unknown): NextResponse {
  const msg = err instanceof Error ? err.message : String(err);
  console.error("signup route error:", msg);
  const hint = /did not initialize|generate|database file|does not exist|P1001|P1003|P2002/i.test(msg)
    ? " The database may not be initialized. Run: npx prisma db push && npm run db:seed"
    : "";
  return NextResponse.json(
    { ok: false, error: "Server error: " + msg + "." + hint },
    { status: 500 }
  );
}

export async function POST(req: Request) {
  try {
    let body: { name?: unknown; email?: unknown; password?: unknown };
    try {
      body = await req.json();
    } catch {
      return NextResponse.json({ ok: false, error: "Invalid request body." }, { status: 400 });
    }

    const name = String(body.name || "").trim();
    const email = String(body.email || "").trim().toLowerCase();
    const password = String(body.password || "");

    if (name.length < 2 || name.length > 80) {
      return NextResponse.json({ ok: false, error: "Enter a valid full name." }, { status: 400 });
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return NextResponse.json({ ok: false, error: "Enter a valid email address." }, { status: 400 });
    }
    if (password.length < 8 || password.length > 100) {
      return NextResponse.json({ ok: false, error: "Password must be 8 to 100 characters." }, { status: 400 });
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      return NextResponse.json(
        { ok: false, error: "An account with this email already exists." },
        { status: 409 }
      );
    }

    const user = await prisma.user.create({
      data: { name, email, passwordHash: hashPassword(password), role: "customer" }
    });

    const res = NextResponse.json({ ok: true });
    res.cookies.set(sessionCookie, makeToken(user.id, user.role), {
      httpOnly: true,
      sameSite: "lax",
      path: "/",
      maxAge: sessionMaxAge
    });
    return res;
  } catch (err) {
    return serverError(err);
  }
}
KO_EOF
mkdir -p "app/api/cart"
cat > "app/api/cart/route.ts" <<'KO_EOF'
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
KO_EOF
mkdir -p "app/api/checkout"
cat > "app/api/checkout/route.ts" <<'KO_EOF'
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
KO_EOF
mkdir -p "app/cart"
cat > "app/cart/page.tsx" <<'KO_EOF'
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
KO_EOF
mkdir -p "app/checkout"
cat > "app/checkout/CheckoutForm.tsx" <<'KO_EOF'
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
KO_EOF
mkdir -p "app/checkout"
cat > "app/checkout/page.tsx" <<'KO_EOF'
import { redirect } from "next/navigation";
import { getSession } from "../../lib/auth";
import { prisma } from "../../lib/prisma";
import CheckoutForm from "./CheckoutForm";

export const metadata = { title: "Checkout - Kaffa Origins" };

export default async function CheckoutPage() {
  const session = await getSession();
  if (!session) redirect("/login?next=/checkout");

  const user = await prisma.user.findUnique({ where: { id: session.userId } });

  return (
    <div className="wrap section">
      <h1>Checkout</h1>
      <p className="sub" style={{ marginBottom: 20 }}>
        Orders ship from our Addis Ababa roastery. We will confirm by phone before dispatch.
      </p>
      <CheckoutForm defaultName={user?.name || ""} />
    </div>
  );
}
KO_EOF
mkdir -p "app"
cat > "app/globals.css" <<'KO_EOF'
/* ============================================================
   Kaffa Origins - warm coffee design system, light + dark
   Cream paper, deep coffee ink, terracotta accent. Chrome is a
   deep espresso brown bar. All values are CSS variables.
   ============================================================ */

:root {
  --bg: #faf6ef;
  --panel: #fffdf8;
  --canvas: #f3ecdf;
  --ink: #2b2018;
  --muted: #7a6a5b;
  --hairline: #e5dccd;
  --chrome: #2f221a;
  --chrome-fg: #f2e9dc;
  --chrome-muted: #b9a893;
  --chrome-line: rgba(255, 255, 255, 0.12);
  --accent: #b35a33;
  --accent-soft: rgba(179, 90, 51, 0.1);
  --btn-bg: #b35a33;
  --btn-fg: #ffffff;
  --btn-h: #96482a;
  --ok: #2c7a4b;
  --ok-soft: rgba(44, 122, 75, 0.1);
  --bad: #b3362e;
  --bad-soft: rgba(179, 54, 46, 0.1);
  --warn: #946200;
  --warn-soft: rgba(148, 98, 0, 0.1);
  --shadow: 0 1px 2px rgba(43, 32, 24, 0.06), 0 4px 12px rgba(43, 32, 24, 0.07);
}

html.dark {
  --bg: #171210;
  --panel: #211a15;
  --canvas: #191410;
  --ink: #ece4da;
  --muted: #a4907d;
  --hairline: #36291f;
  --chrome: #221912;
  --chrome-fg: #ece4da;
  --chrome-muted: #8a7561;
  --chrome-line: rgba(255, 255, 255, 0.1);
  --accent: #c96b42;
  --accent-soft: rgba(201, 107, 66, 0.14);
  --btn-bg: #c96b42;
  --btn-fg: #1c130d;
  --btn-h: #d67d54;
  --shadow: 0 1px 2px rgba(0, 0, 0, 0.35), 0 4px 14px rgba(0, 0, 0, 0.35);
}

* { box-sizing: border-box; }

html, body {
  margin: 0;
  padding: 0;
  background: var(--bg);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  font-size: 15.5px;
  line-height: 1.55;
  transition: background 0.2s, color 0.2s;
}

/* Sticky footer: page fills the viewport, footer always at the bottom. */
body { display: flex; flex-direction: column; min-height: 100vh; }
main { flex: 1 0 auto; width: 100%; }
.site-footer { flex-shrink: 0; margin-top: auto; }

.mono, input.mono, .num {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
}

a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }
h1, h2, h3 { line-height: 1.25; margin: 0 0 10px; }
h1 { font-size: 30px; }
h2 { font-size: 20px; }
p { margin: 0 0 14px; }

.wrap { width: 100%; margin: 0 auto; padding: 0 28px; }

/* ===== Chrome (site header / footer / admin bar) ===== */
.chrome {
  background: var(--chrome);
  color: var(--chrome-fg);
  border-bottom: 1px solid var(--chrome-line);
}
.chrome a { color: var(--chrome-fg); }
.site-header { display: flex; align-items: center; gap: 18px; padding: 14px 0; }
.site-brand {
  font-weight: 800;
  font-size: 18px;
  letter-spacing: 0.02em;
  color: var(--chrome-fg) !important;
  text-decoration: none !important;
  display: flex;
  align-items: center;
  gap: 9px;
}
.site-brand svg { display: block; }
.main-nav { display: flex; gap: 16px; margin-left: auto; }
.main-nav a {
  font-size: 14px;
  color: var(--chrome-muted) !important;
  text-decoration: none !important;
  padding: 6px 2px;
}
.main-nav a:hover, .main-nav a.active { color: var(--chrome-fg) !important; }
.cart-btn {
  position: relative;
  border: 1px solid var(--chrome-line);
  background: transparent;
  color: var(--chrome-fg);
  border-radius: 8px;
  padding: 6px 12px;
  font-size: 13.5px;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 7px;
}
.cart-btn:hover { border-color: var(--accent); }
.cart-count {
  background: var(--accent);
  color: #ffffff;
  border-radius: 999px;
  font-size: 11px;
  min-width: 18px;
  height: 18px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0 4px;
  font-weight: 700;
}
.chrome-actions { display: flex; align-items: center; gap: 10px; }

.site-footer { padding: 30px 0; font-size: 13.5px; color: var(--chrome-muted); }
.footer-row { display: flex; justify-content: space-between; gap: 20px; flex-wrap: wrap; }

/* ===== Hero ===== */
.hero {
  padding: 60px 0 54px;
  border-bottom: 1px solid var(--hairline);
  background: linear-gradient(180deg, var(--canvas) 0%, var(--bg) 100%);
}
.hero-grid { display: flex; gap: 40px; align-items: center; flex-wrap: wrap; }
.hero-copy { flex: 1 1 380px; }
.hero-kicker {
  text-transform: uppercase;
  letter-spacing: 0.16em;
  font-size: 12px;
  font-weight: 700;
  color: var(--accent);
  margin-bottom: 10px;
}
.hero h1 { font-size: 40px; }
.hero .sub { color: var(--muted); font-size: 17px; max-width: 470px; }
.hero-actions { display: flex; gap: 12px; margin-top: 22px; flex-wrap: wrap; }
.hero-art { flex: 0 1 320px; }

/* ===== Buttons, chips, notices ===== */
.btn {
  display: inline-block;
  border: 0;
  background: var(--btn-bg);
  color: var(--btn-fg);
  font-size: 14.5px;
  font-weight: 600;
  border-radius: 8px;
  padding: 10px 18px;
  cursor: pointer;
  text-decoration: none !important;
  text-align: center;
}
.btn:hover { background: var(--btn-h); }
.btn:disabled { opacity: 0.55; cursor: not-allowed; }
.btn.ghost {
  background: transparent;
  color: var(--ink);
  border: 1px solid var(--hairline);
}
.btn.ghost:hover { border-color: var(--accent); color: var(--accent); background: var(--accent-soft); }
/* Ghost buttons on the dark chrome bar (header/footer/admin bar) need
   chrome-colored text, not page-ink, or they vanish in light mode. */
.chrome .btn.ghost {
  color: var(--chrome-fg);
  border-color: var(--chrome-line);
}
.chrome .btn.ghost:hover {
  color: var(--accent);
  border-color: var(--accent);
  background: var(--accent-soft);
}
.btn.danger {
  background: transparent;
  color: var(--bad);
  border: 1px solid var(--bad);
}
.btn.danger:hover { background: var(--bad-soft); }
.btn.sm { padding: 5px 12px; font-size: 12.5px; border-radius: 6px; }
.btn.wide { width: 100%; }

.chip {
  display: inline-block;
  font-size: 11.5px;
  font-weight: 700;
  border-radius: 999px;
  padding: 3px 10px;
}
.chip.ok { background: var(--ok-soft); color: var(--ok); }
.chip.bad { background: var(--bad-soft); color: var(--bad); }
.chip.warn { background: var(--warn-soft); color: var(--warn); }
.chip.neutral { background: var(--accent-soft); color: var(--accent); }

.notice { border-radius: 9px; padding: 11px 14px; font-size: 13.5px; margin: 0 0 14px; }
.notice.ok { background: var(--ok-soft); color: var(--ok); }
.notice.bad { background: var(--bad-soft); color: var(--bad); }
.notice.warn { background: var(--warn-soft); color: var(--warn); }

.error-text { color: var(--bad); font-size: 13.5px; margin: 6px 0 0; }

/* ===== Sections, panels, grids ===== */
.section { padding: 44px 0; }
.section-head { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 20px; gap: 14px; flex-wrap: wrap; }
.sub { color: var(--muted); font-size: 14px; }

.panel {
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 12px;
  box-shadow: var(--shadow);
}
.panel-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  padding: 16px 18px;
  border-bottom: 1px solid var(--hairline);
  flex-wrap: wrap;
}
.panel-head h2 { font-size: 16.5px; margin: 0; }
.panel-body { padding: 18px; }
.panel-body > :last-child { margin-bottom: 0; }

.grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 18px; }
@media (max-width: 800px) { .grid-2 { grid-template-columns: 1fr; } }

/* ===== Product cards ===== */
.prod-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 18px; }
@media (max-width: 900px) { .prod-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 560px) { .prod-grid { grid-template-columns: 1fr; } }
.prod-card {
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 12px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  box-shadow: var(--shadow);
  color: var(--ink);
  text-decoration: none !important;
  transition: border-color 0.15s, transform 0.15s;
}
.prod-card:hover { border-color: var(--accent); transform: translateY(-2px); }
.prod-art { position: relative; height: 150px; display: flex; align-items: center; justify-content: center; }
.prod-art .initials {
  font-size: 34px;
  font-weight: 800;
  color: rgba(255, 255, 255, 0.92);
  letter-spacing: 0.05em;
  text-shadow: 0 1px 4px rgba(0, 0, 0, 0.25);
}
.prod-meta-chips { position: absolute; top: 10px; left: 10px; display: flex; gap: 6px; }
.prod-body { padding: 14px 16px 16px; display: flex; flex-direction: column; gap: 6px; flex: 1; }
.prod-name { font-weight: 700; font-size: 15.5px; color: var(--ink); }
.prod-origin { font-size: 12.5px; color: var(--muted); }
.prod-notes { font-size: 12.5px; color: var(--muted); font-style: italic; }
.prod-foot { display: flex; justify-content: space-between; align-items: center; margin-top: auto; padding-top: 8px; }
.price { font-weight: 700; font-size: 15px; }
.price .unit { font-size: 11.5px; color: var(--muted); font-weight: 400; }

/* ===== Mode toggle (retail / wholesale) ===== */
.mode-switch {
  display: inline-flex;
  border: 1px solid var(--hairline);
  border-radius: 999px;
  padding: 3px;
  gap: 3px;
  background: var(--panel);
}
.mode-switch a {
  border-radius: 999px;
  padding: 6px 16px;
  font-size: 13.5px;
  font-weight: 600;
  color: var(--muted);
  text-decoration: none !important;
}
.mode-switch a.on { background: var(--accent); color: #ffffff; }

/* ===== Forms ===== */
label { display: block; font-size: 13px; font-weight: 600; margin-bottom: 5px; color: var(--ink); }
input, select, textarea {
  width: 100%;
  padding: 9px 12px;
  border: 1px solid var(--hairline);
  border-radius: 8px;
  background: var(--panel);
  color: var(--ink);
  font-size: 14px;
  font-family: inherit;
}
input:focus, select:focus, textarea:focus { outline: 2px solid var(--accent-soft); border-color: var(--accent); }
.form-stack > div { margin-bottom: 14px; }
.form-stack input { max-width: 420px; }
.form-stack input.wide-field { max-width: none; }

/* ===== Tables ===== */
.table-scroll { overflow-x: auto; }
table.ko-table { width: 100%; border-collapse: collapse; font-size: 13.5px; }
.ko-table th {
  text-align: left;
  font-size: 11.5px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--muted);
  padding: 9px 12px;
  border-bottom: 1px solid var(--hairline);
  white-space: nowrap;
}
.ko-table td { padding: 10px 12px; border-bottom: 1px solid var(--hairline); vertical-align: top; }
.ko-table tr:last-child td { border-bottom: 0; }
.ko-table .num { text-align: right; white-space: nowrap; }
.empty { padding: 26px 14px; text-align: center; color: var(--muted); font-size: 14px; }

/* ===== Pager ===== */
.pager {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  padding: 14px 16px;
  border-top: 1px solid var(--hairline);
  flex-wrap: wrap;
}
.pager-info { font-size: 12.5px; color: var(--muted); }
.pager-links { display: flex; gap: 6px; flex-wrap: wrap; }
.pager-btn {
  border: 1px solid var(--hairline);
  background: var(--panel);
  color: var(--ink);
  border-radius: 7px;
  min-width: 32px;
  padding: 5px 10px;
  font-size: 12.5px;
  text-align: center;
  cursor: pointer;
  text-decoration: none !important;
  display: inline-block;
}
.pager-btn:hover { border-color: var(--accent); color: var(--accent); }
.pager-btn.current { background: var(--accent); border-color: var(--accent); color: #ffffff; font-weight: 600; }
.pager-btn.disabled { opacity: 0.45; pointer-events: none; }

/* ===== Order timeline (email-style updates) ===== */
.timeline { list-style: none; margin: 0; padding: 0; }
.timeline li {
  position: relative;
  padding: 0 0 20px 30px;
  border-left: 2px solid var(--hairline);
  margin-left: 8px;
}
.timeline li:last-child { padding-bottom: 4px; border-left-color: transparent; }
.timeline li::before {
  content: "";
  position: absolute;
  left: -7px;
  top: 2px;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--accent);
  border: 2px solid var(--bg);
}
.timeline .t-head { display: flex; justify-content: space-between; gap: 10px; align-items: baseline; flex-wrap: wrap; }
.timeline .t-title { font-weight: 700; font-size: 14px; }
.timeline .t-time { font-size: 12px; color: var(--muted); }
.timeline .t-msg { font-size: 13.5px; color: var(--muted); margin: 4px 0 0; }

/* ===== Theme toggle ===== */
.theme-toggle {
  border: 1px solid var(--chrome-line);
  background: transparent;
  border-radius: 999px;
  width: 34px;
  height: 34px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  color: var(--chrome-fg);
  padding: 0;
}
.theme-toggle:hover { border-color: var(--accent); }

/* ===== Admin chrome ===== */
.admin-bar {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 12px 0;
}
.admin-nav { display: flex; gap: 14px; margin-left: auto; flex-wrap: wrap; }
.admin-nav a {
  font-size: 13.5px;
  color: var(--chrome-muted) !important;
  text-decoration: none !important;
  padding: 4px 2px;
}
.admin-nav a.active, .admin-nav a:hover { color: var(--chrome-fg) !important; }

/* Stat grid */
.stat-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; margin-bottom: 22px; }
@media (max-width: 800px) { .stat-grid { grid-template-columns: 1fr 1fr; } }
@media (max-width: 520px) { .stat-grid { grid-template-columns: 1fr; } }
.stat {
  background: var(--panel);
  border: 1px solid var(--hairline);
  border-radius: 12px;
  padding: 14px 16px;
  box-shadow: var(--shadow);
}
.stat .l { font-size: 12px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.06em; }
.stat .n { font-size: 21px; font-weight: 700; margin-top: 3px; }

/* Page head helper */
.page-head { display: flex; justify-content: space-between; align-items: center; gap: 14px; margin-bottom: 20px; flex-wrap: wrap; }

/* Mobile nav */
@media (max-width: 720px) {
  .main-nav { display: none; }
  .hero h1 { font-size: 30px; }
}
KO_EOF
mkdir -p "app"
cat > "app/layout.tsx" <<'KO_EOF'
import type { Metadata } from "next";
import "./globals.css";
import SiteHeader from "../components/SiteHeader";
import SiteFooter from "../components/SiteFooter";
import { getSession } from "../lib/auth";

export const metadata: Metadata = {
  title: "Kaffa Origins - Ethiopian Coffee Exporter",
  description:
    "Single-origin Ethiopian coffee from Kaffa, Yirgacheffe, Sidama and beyond. Retail roasted bags and wholesale 60kg export lots."
};

// Sets the theme class before first paint to avoid a flash.
const themeInit = `try{if(localStorage.getItem("kaffa-theme")==="dark"||(localStorage.getItem("kaffa-theme")===null&&window.matchMedia("(prefers-color-scheme: dark)").matches)){document.documentElement.classList.add("dark")}}catch(e){}`;

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const session = await getSession();
  return (
    <html lang="en">
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeInit }} />
      </head>
      <body>
        <SiteHeader isAdmin={session?.role === "admin"} signedIn={Boolean(session)} />
        <main>{children}</main>
        <SiteFooter />
      </body>
    </html>
  );
}
KO_EOF
mkdir -p "app/login"
cat > "app/login/LoginForm.tsx" <<'KO_EOF'
"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";

export default function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get("next") || "/orders";
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password })
      });
      const data = await res.json();
      if (res.ok && data.ok) {
        router.push(next);
        router.refresh();
        return;
      }
      setError(data.error || "Could not sign you in.");
    } catch {
      setError("Network error. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="panel" style={{ maxWidth: 440, margin: "0 auto" }}>
      <div className="panel-head"><h2>Sign in</h2></div>
      <div className="panel-body">
        <form className="form-stack" onSubmit={submit}>
          <div>
            <label htmlFor="email">Email</label>
            <input
              id="email"
              type="email"
              className="wide-field"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoComplete="email"
            />
          </div>
          <div>
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              className="wide-field"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              autoComplete="current-password"
            />
          </div>
          {error ? <p className="error-text">{error}</p> : null}
          <button type="submit" className="btn wide" disabled={busy}>
            {busy ? "Signing in..." : "Sign in"}
          </button>
        </form>
        <p className="sub" style={{ marginTop: 14 }}>
          No account yet? <Link href="/signup">Create one</Link>.
        </p>
      </div>
    </div>
  );
}
KO_EOF
mkdir -p "app/login"
cat > "app/login/page.tsx" <<'KO_EOF'
import { Suspense } from "react";
import LoginForm from "./LoginForm";

export const metadata = { title: "Sign in - Kaffa Origins" };

export default function LoginPage() {
  return (
    <div className="wrap section">
      <h1 style={{ textAlign: "center", marginBottom: 24 }}>Welcome back</h1>
      <Suspense fallback={<p className="empty">Loading...</p>}>
        <LoginForm />
      </Suspense>
    </div>
  );
}
KO_EOF
mkdir -p "app/orders/[orderNo]"
cat > "app/orders/[orderNo]/page.tsx" <<'KO_EOF'
import Link from "next/link";
import { notFound } from "next/navigation";
import { prisma } from "../../../lib/prisma";
import { getSession } from "../../../lib/auth";
import { etb } from "../../../lib/money";
import {
  ORDER_STATUS_LABELS,
  STATUS_CHIP_CLASS,
  BUYER_TYPE_LABELS,
  STATUS_MESSAGES
} from "../../../lib/orderStatus";

export async function generateMetadata({ params }: { params: { orderNo: string } }) {
  return { title: "Order " + params.orderNo + " - Kaffa Origins" };
}

export default async function OrderDetailPage({ params }: { params: { orderNo: string } }) {
  const session = await getSession();
  if (!session) notFound();

  const order = await prisma.order.findUnique({
    where: { orderNo: params.orderNo },
    include: { items: true, events: { orderBy: { createdAt: "desc" } } }
  });

  // Ownership check: a customer can only see their own orders.
  if (!order || (order.userId !== session.userId && session.role !== "admin")) notFound();

  return (
    <div className="wrap section">
      <p className="sub" style={{ marginBottom: 16 }}>
        <Link href="/orders" className="sub">Your orders</Link> / <span className="mono">{order.orderNo}</span>
      </p>
      <div className="page-head">
        <h1>Order {order.orderNo}</h1>
        <span className={"chip " + (STATUS_CHIP_CLASS[order.status] || "neutral")}>
          {ORDER_STATUS_LABELS[order.status] || order.status}
        </span>
      </div>

      <div className="grid-2" style={{ alignItems: "start" }}>
        <div>
          <div className="panel" style={{ marginBottom: 18 }}>
            <div className="panel-head"><h2>Items</h2></div>
            <div className="table-scroll">
              <table className="ko-table">
                <thead>
                  <tr>
                    <th>Product</th>
                    <th>Type</th>
                    <th className="num">Unit</th>
                    <th className="num">Qty</th>
                    <th className="num">Total</th>
                  </tr>
                </thead>
                <tbody>
                  {order.items.map((i) => (
                    <tr key={i.id}>
                      <td>{i.productName}</td>
                      <td>{BUYER_TYPE_LABELS[i.priceType] || i.priceType}</td>
                      <td className="num">{etb(i.unitPriceCents)}</td>
                      <td className="num">{i.qty}</td>
                      <td className="num">{etb(i.lineTotalCents)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="pager">
              <span className="pager-info">Subtotal {etb(order.subtotalCents)} - Shipping {etb(order.shippingCents)}</span>
              <span className="pager-info" style={{ fontWeight: 700, color: "var(--ink)" }}>
                Total {etb(order.totalCents)}
              </span>
            </div>
          </div>
          <div className="panel">
            <div className="panel-head"><h2>Delivery address</h2></div>
            <div className="panel-body sub">
              {order.name} - {order.phone}
              <br />
              {order.addressLine}, {order.city}
              <br />
              {order.email}
            </div>
          </div>
        </div>
        <div className="panel">
          <div className="panel-head"><h2>Updates</h2></div>
          <div className="panel-body">
            <ul className="timeline">
              {order.events.map((e) => (
                <li key={e.id}>
                  <div className="t-head">
                    <span className="t-title">{ORDER_STATUS_LABELS[e.status] || e.status}</span>
                    <span className="t-time">{e.createdAt.toISOString().replace("T", " ").slice(0, 16)}</span>
                  </div>
                  <p className="t-msg">{e.message || STATUS_MESSAGES[e.status]}</p>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
KO_EOF
mkdir -p "app/orders"
cat > "app/orders/page.tsx" <<'KO_EOF'
import Link from "next/link";
import { redirect } from "next/navigation";
import { prisma } from "../../lib/prisma";
import { getSession } from "../../lib/auth";
import { etb } from "../../lib/money";
import {
  ORDER_STATUS_LABELS,
  STATUS_CHIP_CLASS,
  BUYER_TYPE_LABELS
} from "../../lib/orderStatus";
import Pager from "../../components/Pager";

export const metadata = { title: "Your orders - Kaffa Origins" };

const PER_PAGE = 10;

export default async function OrdersPage({
  searchParams
}: {
  searchParams: { page?: string };
}) {
  const session = await getSession();
  if (!session) redirect("/login?next=/orders");

  const page = Math.max(1, Math.floor(Number(searchParams.page) || 1) || 1);

  const [total, orders] = await Promise.all([
    prisma.order.count({ where: { userId: session.userId } }),
    prisma.order.findMany({
      where: { userId: session.userId },
      orderBy: { createdAt: "desc" },
      skip: (page - 1) * PER_PAGE,
      take: PER_PAGE,
      include: { items: true }
    })
  ]);

  return (
    <div className="wrap section">
      <h1>Your orders</h1>
      <p className="sub" style={{ marginBottom: 20 }}>
        Every order gets email-style status updates you can follow on its detail page.
      </p>
      <div className="panel">
        <div className="panel-head"><h2>Order history</h2></div>
        {orders.length === 0 ? (
          <p className="empty">No orders yet. <Link href="/shop">Browse the shop</Link>.</p>
        ) : (
          <>
            <div className="table-scroll">
              <table className="ko-table">
                <thead>
                  <tr>
                    <th>Order</th>
                    <th>Date</th>
                    <th>Type</th>
                    <th className="num">Items</th>
                    <th className="num">Total</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {orders.map((o) => (
                    <tr key={o.id}>
                      <td><Link href={"/orders/" + o.orderNo} className="mono">{o.orderNo}</Link></td>
                      <td>{o.createdAt.toISOString().slice(0, 10)}</td>
                      <td>{BUYER_TYPE_LABELS[o.buyerType] || o.buyerType}</td>
                      <td className="num">{o.items.reduce((s, i) => s + i.qty, 0)}</td>
                      <td className="num">{etb(o.totalCents)}</td>
                      <td>
                        <span className={"chip " + (STATUS_CHIP_CLASS[o.status] || "neutral")}>
                          {ORDER_STATUS_LABELS[o.status] || o.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Pager page={page} total={total} perPage={PER_PAGE} basePath="/orders" />
          </>
        )}
      </div>
    </div>
  );
}
KO_EOF
mkdir -p "app"
cat > "app/page.tsx" <<'KO_EOF'
import Link from "next/link";
import { prisma } from "../lib/prisma";
import ProductCard from "../components/ProductCard";

async function getFeatured() {
  try {
    return await prisma.product.findMany({
      where: { featured: true, active: true },
      orderBy: { name: "asc" },
      take: 3
    });
  } catch {
    return [];
  }
}

function HeroArt() {
  return (
    <svg viewBox="0 0 200 200" width="100%" aria-hidden="true">
      <ellipse cx="100" cy="100" rx="52" ry="72" transform="rotate(-24 100 100)" fill="#8a4a2b" />
      <ellipse cx="100" cy="100" rx="52" ry="72" transform="rotate(-24 100 100)" fill="url(#beanShade)" />
      <path d="M100 28c-18 24-18 40 0 72s18 48 0 72" fill="none" stroke="#faf6ef" strokeWidth="5" transform="rotate(-24 100 100)" />
      <defs>
        <radialGradient id="beanShade" cx="35%" cy="30%">
          <stop offset="0%" stopColor="#c97a4f" stopOpacity="0.9" />
          <stop offset="100%" stopColor="#5a3020" stopOpacity="0.9" />
        </radialGradient>
      </defs>
    </svg>
  );
}

export default async function LandingPage() {
  const featured = await getFeatured();

  return (
    <>
      <section className="hero">
        <div className="wrap hero-grid">
          <div className="hero-copy">
            <div className="hero-kicker">From the birthplace of coffee</div>
            <h1>Single-origin Ethiopian coffee, shipped from Addis Ababa.</h1>
            <p className="sub">
              Kaffa Origins works directly with washing stations and smallholder farmers across
              Ethiopia&apos;s famous growing regions. Buy roasted 250g bags as a retail customer,
              or full 60kg export lots at wholesale pricing.
            </p>
            <div className="hero-actions">
              <Link href="/shop?mode=retail" className="btn">Shop retail</Link>
              <Link href="/shop?mode=wholesale" className="btn ghost">Wholesale lots</Link>
            </div>
          </div>
          <div className="hero-art">
            <HeroArt />
          </div>
        </div>
      </section>

      <section className="section">
        <div className="wrap">
          <div className="section-head">
            <h2>Featured coffees</h2>
            <Link href="/shop" className="sub">Browse the full catalog -></Link>
          </div>
          {featured.length === 0 ? (
            <p className="empty">No products yet. Run the database seed to load the catalog.</p>
          ) : (
            <div className="prod-grid">
              {featured.map((p) => (
                <ProductCard key={p.id} p={p} mode="retail" />
              ))}
            </div>
          )}
        </div>
      </section>

      <section className="section">
        <div className="wrap grid-2">
          <div>
            <h2>Our story</h2>
            <p className="sub">
              Coffee was born in the forests of Kaffa, in southwestern Ethiopia. We take our name
              from that forest. Every lot we sell is traceable to a single washing station or
              cooperative, cupped at our Addis Ababa roastery, and shipped within days of roast
              (retail) or within weeks of processing (wholesale green).
            </p>
          </div>
          <div>
            <h2>Buying wholesale</h2>
            <p className="sub">
              Wholesale orders are priced per 60kg bag of green coffee with a minimum of 5 bags per
              lot line and a flat ETB 4,500 freight charge. Retail orders ship free over ETB 1,500
              (otherwise a flat ETB 250). Switch between the two anytime from the Shop page.
            </p>
          </div>
        </div>
      </section>
    </>
  );
}
KO_EOF
mkdir -p "app/product/[slug]"
cat > "app/product/[slug]/AddToCart.tsx" <<'KO_EOF'
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
KO_EOF
mkdir -p "app/product/[slug]"
cat > "app/product/[slug]/page.tsx" <<'KO_EOF'
import Link from "next/link";
import { notFound } from "next/navigation";
import { prisma } from "../../../lib/prisma";
import { etb } from "../../../lib/money";
import { WHOLESALE_MOQ } from "../../../lib/money";
import AddToCart from "./AddToCart";

type Params = { slug: string };
type SearchParams = { mode?: string };

export async function generateMetadata({ params }: { params: Params }) {
  try {
    const p = await prisma.product.findUnique({ where: { slug: params.slug } });
    return { title: p ? p.name + " - Kaffa Origins" : "Product - Kaffa Origins" };
  } catch {
    return { title: "Product - Kaffa Origins" };
  }
}

export default async function ProductPage({
  params,
  searchParams
}: {
  params: Params;
  searchParams: SearchParams;
}) {
  let p = null;
  try {
    p = await prisma.product.findUnique({ where: { slug: params.slug } });
  } catch {
    p = null;
  }
  if (!p || !p.active) notFound();

  const mode = searchParams.mode === "wholesale" && p.wholesaleEligible ? "wholesale" : "retail";
  const wholesale = mode === "wholesale";
  const price = wholesale ? p.wholesalePriceCents : p.retailPriceCents;
  const stock = wholesale ? p.wholesaleStock : p.retailStock;
  const initials = p.name
    .split(" ")
    .map((w) => w.charAt(0))
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <div className="wrap section">
      <p className="sub" style={{ marginBottom: 18 }}>
        <Link href="/shop?mode=retail" className="sub">Retail</Link>
        {" / "}
        <Link href={"/shop?mode=" + mode} className="sub">{wholesale ? "Wholesale" : "Shop"}</Link>
        {" / "}
        {p.name}
      </p>
      <div className="grid-2">
        <div
          className="prod-art"
          style={{
            borderRadius: 14,
            height: 320,
            background:
              "linear-gradient(135deg, hsl(" + p.hue + ", 45%, 55%), hsl(" + ((p.hue + 40) % 360) + ", 50%, 38%))"
          }}
        >
          <span className="initials" style={{ fontSize: 64 }}>{initials}</span>
          <span className="prod-meta-chips">
            <span className="chip neutral">{p.roast}</span>
            <span className="chip neutral">{p.process}</span>
          </span>
        </div>
        <div>
          <h1>{p.name}</h1>
          <p className="sub">{p.origin} - {p.process} process - {p.roast} roast</p>
          <p style={{ margin: "14px 0" }}>{p.description}</p>
          <p className="prod-notes">Tasting notes: {p.tastingNotes}</p>
          <div className="section-head" style={{ marginTop: 20 }}>
            <span className="price" style={{ fontSize: 22 }}>
              {etb(price)}
              <span className="unit"> / {wholesale ? "60kg bag" : "250g bag"}</span>
            </span>
            <span className={"chip " + (stock > 0 ? "ok" : "bad")}>
              {stock > 0 ? stock + " in stock" : "Out of stock"}
            </span>
          </div>
          {wholesale ? (
            <p className="notice">Wholesale: minimum {WHOLESALE_MOQ} bags per line, flat ETB 4,500 freight.</p>
          ) : null}
          {p.wholesaleEligible && !wholesale ? (
            <p className="sub" style={{ marginBottom: 12 }}>
              Also available wholesale -{" "}
              <Link href={"/product/" + p.slug + "?mode=wholesale"} className="sub">view wholesale pricing</Link>.
            </p>
          ) : null}
          <AddToCart slug={p.slug} priceType={mode} stock={stock} />
        </div>
      </div>
    </div>
  );
}
KO_EOF
mkdir -p "app/shop"
cat > "app/shop/page.tsx" <<'KO_EOF'
import Link from "next/link";
import { prisma } from "../../lib/prisma";
import ProductCard from "../../components/ProductCard";
import { WHOLESALE_MOQ } from "../../lib/money";

export const metadata = { title: "Shop - Kaffa Origins" };

type SearchParams = { mode?: string };

export default async function ShopPage({ searchParams }: { searchParams: SearchParams }) {
  const mode = searchParams.mode === "wholesale" ? "wholesale" : "retail";
  const wholesale = mode === "wholesale";

  let products: Awaited<ReturnType<typeof prisma.product.findMany>> = [];
  try {
    products = await prisma.product.findMany({
      where: wholesale
        ? { active: true, wholesaleEligible: true }
        : { active: true },
      orderBy: { name: "asc" }
    });
  } catch {
    products = [];
  }

  const otherHref = wholesale ? "/shop?mode=retail" : "/shop?mode=wholesale";

  return (
    <div className="wrap section">
      <div className="page-head">
        <h1>{wholesale ? "Wholesale lots" : "Roasted coffee"}</h1>
        <div className="mode-switch">
          <Link href="/shop?mode=retail" className={wholesale ? "" : "on"}>Retail</Link>
          <Link href="/shop?mode=wholesale" className={wholesale ? "on" : ""}>Wholesale</Link>
        </div>
      </div>
      <p className="sub" style={{ marginBottom: 22 }}>
        {wholesale
          ? "Green coffee priced per 60kg export bag. Minimum " + WHOLESALE_MOQ + " bags per lot line, flat ETB 4,500 freight per order."
          : "Freshly roasted 250g bags. Flat ETB 250 shipping, free over ETB 1,500."}
      </p>
      {!wholesale && products.some((p) => !p.wholesaleEligible) ? (
        <p className="sub" style={{ marginBottom: 22 }}>
          Some coffees are export-only - <Link href={otherHref} className="sub">switch to wholesale</Link> to see them.
        </p>
      ) : null}
      {products.length === 0 ? (
        <p className="empty">No products available in this mode right now.</p>
      ) : (
        <div className="prod-grid">
          {products.map((p) => (
            <ProductCard key={p.id} p={p} mode={mode} />
          ))}
        </div>
      )}
    </div>
  );
}
KO_EOF
mkdir -p "app/signup"
cat > "app/signup/page.tsx" <<'KO_EOF'
import SignupForm from "./SignupForm";

export const metadata = { title: "Create account - Kaffa Origins" };

export default function SignupPage() {
  return (
    <div className="wrap section">
      <h1 style={{ textAlign: "center", marginBottom: 24 }}>Join Kaffa Origins</h1>
      <SignupForm />
    </div>
  );
}
KO_EOF
mkdir -p "app/signup"
cat > "app/signup/SignupForm.tsx" <<'KO_EOF'
"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

export default function SignupForm() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    setBusy(true);
    try {
      const res = await fetch("/api/auth/signup", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, email, password })
      });
      const data = await res.json();
      if (res.ok && data.ok) {
        router.push("/shop");
        router.refresh();
        return;
      }
      setError(data.error || "Could not create your account.");
    } catch {
      setError("Network error. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="panel" style={{ maxWidth: 440, margin: "0 auto" }}>
      <div className="panel-head"><h2>Create account</h2></div>
      <div className="panel-body">
        <form className="form-stack" onSubmit={submit}>
          <div>
            <label htmlFor="name">Full name</label>
            <input id="name" className="wide-field" value={name} onChange={(e) => setName(e.target.value)} required maxLength={80} />
          </div>
          <div>
            <label htmlFor="email">Email</label>
            <input id="email" type="email" className="wide-field" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" />
          </div>
          <div>
            <label htmlFor="password">Password (min 8 characters)</label>
            <input id="password" type="password" className="wide-field" value={password} onChange={(e) => setPassword(e.target.value)} required minLength={8} autoComplete="new-password" />
          </div>
          {error ? <p className="error-text">{error}</p> : null}
          <button type="submit" className="btn wide" disabled={busy}>
            {busy ? "Creating..." : "Create account"}
          </button>
        </form>
        <p className="sub" style={{ marginTop: 14 }}>
          Already registered? <Link href="/login">Sign in</Link>.
        </p>
      </div>
    </div>
  );
}
KO_EOF
mkdir -p "components"
cat > "components/CartBadge.tsx" <<'KO_EOF'
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
KO_EOF
mkdir -p "components"
cat > "components/Pager.tsx" <<'KO_EOF'
import Link from "next/link";

type Props = {
  page: number;
  total: number;
  perPage: number;
  basePath: string;
  extraParams?: Record<string, string>;
};

// Windowed Link-based pager (10 rows per page everywhere in this app).
export default function Pager({ page, total, perPage, basePath, extraParams }: Props) {
  const pages = Math.max(1, Math.ceil(total / perPage));
  if (total === 0) return null;

  const href = (p: number) => {
    const params = new URLSearchParams(extraParams || {});
    params.set("page", String(p));
    return basePath + "?" + params.toString();
  };

  const window: number[] = [];
  const start = Math.max(1, Math.min(page - 2, pages - 4));
  const end = Math.min(pages, start + 4);
  for (let p = start; p <= end; p++) window.push(p);

  return (
    <div className="pager">
      <span className="pager-info">
        Showing {(page - 1) * perPage + 1}-{Math.min(page * perPage, total)} of {total}
      </span>
      <span className="pager-links">
        <Link href={href(Math.max(1, page - 1))} className={"pager-btn" + (page <= 1 ? " disabled" : "")}>
          Prev
        </Link>
        {start > 1 ? <Link href={href(1)} className="pager-btn">1</Link> : null}
        {start > 2 ? <span className="pager-btn disabled">...</span> : null}
        {window.map((p) => (
          <Link key={p} href={href(p)} className={"pager-btn" + (p === page ? " current" : "")}>
            {p}
          </Link>
        ))}
        {end < pages - 1 ? <span className="pager-btn disabled">...</span> : null}
        {end < pages ? <Link href={href(pages)} className="pager-btn">{pages}</Link> : null}
        <Link href={href(Math.min(pages, page + 1))} className={"pager-btn" + (page >= pages ? " disabled" : "")}>
          Next
        </Link>
      </span>
    </div>
  );
}
KO_EOF
mkdir -p "components"
cat > "components/ProductCard.tsx" <<'KO_EOF'
import Link from "next/link";
import { etb } from "../lib/money";

type CardProduct = {
  slug: string;
  name: string;
  origin: string;
  process: string;
  roast: string;
  hue: number;
  retailPriceCents: number;
  retailStock: number;
  wholesaleEligible: boolean;
  wholesalePriceCents: number;
  wholesaleStock: number;
};

// Server component. Renders gradient art derived from the product hue
// so the catalog looks designed without shipping any binary images.
export default function ProductCard({ p, mode }: { p: CardProduct; mode: string }) {
  const wholesale = mode === "wholesale";
  const price = wholesale ? p.wholesalePriceCents : p.retailPriceCents;
  const stock = wholesale ? p.wholesaleStock : p.retailStock;
  const initials = p.name
    .split(" ")
    .map((w) => w.charAt(0))
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <Link href={"/product/" + p.slug + (wholesale ? "?mode=wholesale" : "")} className="prod-card">
      <div
        className="prod-art"
        style={{ background: "linear-gradient(135deg, hsl(" + p.hue + ", 45%, 55%), hsl(" + ((p.hue + 40) % 360) + ", 50%, 38%))" }}
      >
        <span className="initials">{initials}</span>
        <span className="prod-meta-chips">
          <span className="chip neutral">{p.roast}</span>
          <span className="chip neutral">{p.process}</span>
        </span>
      </div>
      <div className="prod-body">
        <span className="prod-name">{p.name}</span>
        <span className="prod-origin">{p.origin}</span>
        <span className="prod-foot">
          <span className="price">
            {etb(price)}
            <span className="unit"> / {wholesale ? "60kg bag" : "250g"}</span>
          </span>
          <span className={"chip " + (stock > 0 ? "ok" : "bad")}>
            {stock > 0 ? stock + " in stock" : "Out of stock"}
          </span>
        </span>
      </div>
    </Link>
  );
}
KO_EOF
mkdir -p "components"
cat > "components/SiteFooter.tsx" <<'KO_EOF'
export default function SiteFooter() {
  return (
    <footer className="chrome site-footer">
      <div className="wrap footer-row">
        <span>Kaffa Origins PLC - Addis Ababa, Ethiopia - coffee from its birthplace</span>
        <span>Fictional demo store for a portfolio project. No real orders are fulfilled.</span>
      </div>
    </footer>
  );
}
KO_EOF
mkdir -p "components"
cat > "components/SiteHeader.tsx" <<'KO_EOF'
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import ThemeToggle from "./ThemeToggle";
import CartBadge from "./CartBadge";

// Brand mark: a coffee bean drawn as an inline SVG (ASCII-safe, no deps).
function BrandMark() {
  return (
    <svg width="26" height="26" viewBox="0 0 24 24" aria-hidden="true">
      <ellipse cx="12" cy="12" rx="9" ry="11" fill="#b35a33" />
      <path d="M12 1c-3 4-3 6 0 11s3 7 0 11" fill="none" stroke="#faf6ef" strokeWidth="1.8" />
    </svg>
  );
}

type Props = {
  isAdmin: boolean;
  signedIn: boolean;
};

export default function SiteHeader({ isAdmin, signedIn }: Props) {
  const path = usePathname();
  const on = (href: string) => (path === href || (href !== "/" && path.startsWith(href + "/")) ? " active" : "");

  return (
    <div className="chrome">
      <div className="wrap site-header">
        <Link href="/" className="site-brand">
          <BrandMark />
          <span>Kaffa Origins</span>
        </Link>
        <nav className="main-nav">
          <Link href="/" className={on("/")}>Home</Link>
          <Link href="/shop" className={on("/shop")}>Shop</Link>
          <Link href="/orders" className={on("/orders")}>Orders</Link>
          {isAdmin ? <Link href="/admin" className={on("/admin")}>Admin</Link> : null}
        </nav>
        <div className="chrome-actions">
          <CartBadge />
          {signedIn ? (
            <a href="/api/auth/logout" className="btn ghost sm">Sign out</a>
          ) : (
            <Link href="/login" className="btn ghost sm">Sign in</Link>
          )}
          <ThemeToggle />
        </div>
      </div>
    </div>
  );
}
KO_EOF
mkdir -p "components"
cat > "components/ThemeToggle.tsx" <<'KO_EOF'
"use client";

import { useEffect, useState } from "react";

// Shared inline sun/moon icons (kept ASCII-only).
function SunIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
    </svg>
  );
}

function MoonIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
      <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" />
    </svg>
  );
}

export default function ThemeToggle() {
  const [dark, setDark] = useState(false);

  useEffect(() => {
    setDark(document.documentElement.classList.contains("dark"));
  }, []);

  function toggle() {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle("dark", next);
    try {
      window.localStorage.setItem("kaffa-theme", next ? "dark" : "light");
    } catch {
      // storage unavailable - theme applies for this page only
    }
  }

  return (
    <button
      type="button"
      className="theme-toggle"
      onClick={toggle}
      aria-label={dark ? "Switch to light theme" : "Switch to dark theme"}
      title={dark ? "Light theme" : "Dark theme"}
    >
      {dark ? <SunIcon /> : <MoonIcon />}
    </button>
  );
}
KO_EOF
mkdir -p "lib"
cat > "lib/auth.ts" <<'KO_EOF'
import { createHmac, randomBytes, scryptSync, timingSafeEqual } from "crypto";
import { cookies } from "next/headers";

const SESSION_COOKIE = "kaffa_session";
const MAX_AGE = 60 * 60 * 8; // 8 hours

function secret(): string {
  return process.env.SESSION_SECRET || "dev-secret";
}

function sign(payload: string): string {
  return createHmac("sha256", secret()).update(payload).digest("hex");
}

export function makeToken(userId: string, role: string): string {
  const payload = userId + "|" + role + "|" + Date.now().toString();
  return payload + "|" + sign(payload);
}

export function verifyToken(token: string | undefined): {
  userId: string;
  role: string;
} | null {
  if (!token) return null;
  const parts = token.split("|");
  if (parts.length !== 4) return null;
  const [userId, role, issued, sig] = parts;
  const expected = sign(userId + "|" + role + "|" + issued);
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  const age = (Date.now() - Number(issued)) / 1000;
  if (!Number.isFinite(age) || age < 0 || age >= MAX_AGE) return null;
  return { userId, role };
}

// scrypt password hashing: salt is stored with the hash.
export function hashPassword(password: string): string {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(password, salt, 64).toString("hex");
  return salt + ":" + hash;
}

export function verifyPassword(password: string, stored: string): boolean {
  const [salt, hash] = stored.split(":");
  if (!salt || !hash) return false;
  const candidate = scryptSync(password, salt, 64);
  const expected = Buffer.from(hash, "hex");
  if (candidate.length !== expected.length) return false;
  return timingSafeEqual(candidate, expected);
}

export async function getSession(): Promise<{
  userId: string;
  role: string;
} | null> {
  const store = cookies();
  return verifyToken(store.get(SESSION_COOKIE)?.value);
}

export const sessionCookie = SESSION_COOKIE;
export const sessionMaxAge = MAX_AGE;

// Simple in-memory login rate limiter (5 failures per 15 minutes).
const attempts = new Map<string, { count: number; first: number }>();
const WINDOW_MS = 15 * 60 * 1000;

export function loginBlocked(key: string): boolean {
  const rec = attempts.get(key);
  if (!rec) return false;
  if (Date.now() - rec.first > WINDOW_MS) {
    attempts.delete(key);
    return false;
  }
  return rec.count >= 5;
}

export function recordFailedLogin(key: string): void {
  const now = Date.now();
  const rec = attempts.get(key);
  if (!rec || now - rec.first > WINDOW_MS) {
    attempts.set(key, { count: 1, first: now });
  } else {
    rec.count += 1;
  }
}

export function clearLoginAttempts(key: string): void {
  attempts.delete(key);
}
KO_EOF
mkdir -p "lib"
cat > "lib/cart.ts" <<'KO_EOF'
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
KO_EOF
mkdir -p "lib"
cat > "lib/money.ts" <<'KO_EOF'
// All amounts are stored as integer cents to avoid floating point drift.
// ETB has 2 decimal places in this demo.

export function etb(cents: number): string {
  const n = Number(cents) || 0;
  const sign = n < 0 ? "-" : "";
  const abs = Math.abs(Math.round(n));
  const whole = Math.floor(abs / 100);
  const frac = String(abs % 100).padStart(2, "0");
  return sign + "ETB " + whole.toLocaleString("en-US") + "." + frac;
}

export function toCents(amount: string | number): number | null {
  const n = Number(amount);
  if (!Number.isFinite(n)) return null;
  return Math.round(n * 100);
}

// Minimum bags per wholesale lot line. Kept here because this file is
// client-safe (no node:crypto or prisma imports).
export const WHOLESALE_MOQ = 5;
KO_EOF
mkdir -p "lib"
cat > "lib/orderStatus.ts" <<'KO_EOF'
// Client-safe constants (no node imports) for client components.

export const ORDER_STATUSES: string[] = [
  "placed",
  "confirmed",
  "roasting",
  "shipped",
  "delivered",
  "cancelled"
];

export const ORDER_STATUS_LABELS: Record<string, string> = {
  placed: "Order placed",
  confirmed: "Confirmed",
  roasting: "In the roastery",
  shipped: "Shipped",
  delivered: "Delivered",
  cancelled: "Cancelled"
};

// Email-style messages the customer sees as their order timeline.
export const STATUS_MESSAGES: Record<string, string> = {
  placed:
    "We received your order. You will get a confirmation within one business day.",
  confirmed:
    "Your order is confirmed and has been queued at our Addis Ababa roastery.",
  roasting:
    "Your coffee is being roasted to order and packed fresh. Nothing sits on a shelf here.",
  shipped:
    "Your order has left our facility and is on its way. Track it with the courier code we send by phone.",
  delivered:
    "Your order has been delivered. Thank you for buying from Ethiopian farms - enjoy the cup.",
  cancelled:
    "This order was cancelled. Any payment made is refunded to the original payment method within 5 business days."
};

export const STATUS_CHIP_CLASS: Record<string, string> = {
  placed: "warn",
  confirmed: "ok",
  roasting: "warn",
  shipped: "ok",
  delivered: "ok",
  cancelled: "bad"
};

export const BUYER_TYPE_LABELS: Record<string, string> = {
  retail: "Retail",
  wholesale: "Wholesale"
};
KO_EOF
mkdir -p "lib"
cat > "lib/prices.ts" <<'KO_EOF'
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
KO_EOF
mkdir -p "lib"
cat > "lib/prisma.ts" <<'KO_EOF'
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma = globalForPrisma.prisma ?? new PrismaClient();

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
KO_EOF
cat > "middleware.ts" <<'KO_EOF'
import { NextRequest, NextResponse } from "next/server";

// Authenticated areas are never cached, so the browser back button can
// never reveal an order page or the admin console after logout.
export function middleware(req: NextRequest) {
  const res = NextResponse.next();
  res.headers.set("Cache-Control", "no-store, must-revalidate");
  return res;
}

export const config = {
  matcher: ["/orders/:path*", "/admin/:path*", "/checkout/:path*"]
};
KO_EOF
cat > "next.config.mjs" <<'KO_EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {};

export default nextConfig;
KO_EOF
cat > "package.json" <<'KO_EOF'
{
  "name": "kaffa-origins",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "db:push": "prisma db push",
    "db:seed": "tsx prisma/seed.ts"
  },
  "dependencies": {
    "@prisma/client": "^5.22.0",
    "next": "^14.2.5",
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/node": "^20.14.0",
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "prisma": "^5.22.0",
    "tsx": "^4.19.0",
    "typescript": "^5.5.4"
  }
}
KO_EOF
mkdir -p "prisma"
cat > "prisma/schema.prisma" <<'KO_EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}

model User {
  id           String   @id @default(cuid())
  email        String   @unique
  name         String
  passwordHash String
  role         String   @default("customer")
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
  orders       Order[]
}

model Product {
  id              String      @id @default(cuid())
  slug            String      @unique
  name            String
  origin          String
  process         String
  roast           String
  description     String
  tastingNotes    String
  hue             Int         @default(24)
  featured        Boolean     @default(false)
  active          Boolean     @default(true)
  retailPriceCents Int
  retailStock     Int         @default(0)
  wholesaleEligible Boolean   @default(false)
  wholesalePriceCents Int      @default(0)
  wholesaleStock  Int         @default(0)
  createdAt       DateTime    @default(now())
  orderItems      OrderItem[]
}

model Order {
  id            String       @id @default(cuid())
  orderNo       String       @unique
  userId        String
  user          User         @relation(fields: [userId], references: [id])
  buyerType     String       @default("retail")
  status        String       @default("placed")
  name          String
  email         String
  phone         String
  city          String
  addressLine   String
  subtotalCents Int
  shippingCents Int
  totalCents    Int
  createdAt     DateTime     @default(now())
  updatedAt     DateTime     @updatedAt
  items         OrderItem[]
  events        OrderEvent[]

  @@index([userId])
  @@index([status])
}

model OrderItem {
  id            String   @id @default(cuid())
  orderId       String
  order         Order    @relation(fields: [orderId], references: [id])
  productId     String
  product       Product  @relation(fields: [productId], references: [id])
  productName   String
  priceType     String
  unitPriceCents Int
  qty           Int
  lineTotalCents Int

  @@index([orderId])
}

model OrderEvent {
  id        String   @id @default(cuid())
  orderId   String
  order     Order    @relation(fields: [orderId], references: [id])
  status    String
  message   String
  createdAt DateTime @default(now())

  @@index([orderId])
}
KO_EOF
mkdir -p "prisma"
cat > "prisma/seed.ts" <<'KO_EOF'
import { PrismaClient } from "@prisma/client";
import { randomBytes, scryptSync } from "crypto";

const prisma = new PrismaClient();

function hash(password: string): string {
  const salt = randomBytes(16).toString("hex");
  return salt + ":" + scryptSync(password, salt, 64).toString("hex");
}

async function main() {
  console.log("Seeding Kaffa Origins demo data...");

  await prisma.orderEvent.deleteMany();
  await prisma.orderItem.deleteMany();
  await prisma.order.deleteMany();
  await prisma.product.deleteMany();
  await prisma.user.deleteMany();

  const admin = await prisma.user.create({
    data: {
      email: "admin@kaffaorigins.et",
      name: "Roastery Admin",
      passwordHash: hash("admin-pass-2026"),
      role: "admin"
    }
  });
  const demo = await prisma.user.create({
    data: {
      email: "daniel@kaffaorigins.et",
      name: "Daniel Tadesse",
      passwordHash: hash("demo-pass-2026"),
      role: "customer"
    }
  });
  await prisma.user.create({
    data: {
      email: "sara@example.com",
      name: "Sara Bekele",
      passwordHash: hash("customer-pass-2026"),
      role: "customer"
    }
  });
  console.log("Users created.");

  // Retail prices are per 250g roasted bag, wholesale per 60kg green bag.
  const products = [
    {
      slug: "yirgacheffe-washed",
      name: "Yirgacheffe Washed",
      origin: "Gedeo, Yirgacheffe",
      process: "Washed",
      roast: "Light",
      description:
        "The classic southern Ethiopian cup: jasmine in the aroma, bright bergamot acidity and a clean tea-like finish.",
      tastingNotes: "Jasmine, bergamot, black tea",
      hue: 28,
      featured: true,
      retailPriceCents: 48000,
      retailStock: 42,
      wholesaleEligible: true,
      wholesalePriceCents: 1250000,
      wholesaleStock: 30
    },
    {
      slug: "sidama-natural",
      name: "Sidama Natural",
      origin: "Sidama",
      process: "Natural",
      roast: "Medium",
      description:
        "Sun-dried on raised beds, bursting with berry sweetness and a heavy chocolate body that shines in espresso.",
      tastingNotes: "Strawberry, blueberry, cocoa",
      hue: 350,
      featured: true,
      retailPriceCents: 42500,
      retailStock: 55,
      wholesaleEligible: true,
      wholesalePriceCents: 1050000,
      wholesaleStock: 40
    },
    {
      slug: "guji-hambela",
      name: "Guji Hambela",
      origin: "Guji",
      process: "Washed",
      roast: "Light",
      description:
        "A highland washed lot with stone fruit sweetness, floral lift and a syrupy mouthfeel.",
      tastingNotes: "Peach, apricot, honey",
      hue: 45,
      featured: true,
      retailPriceCents: 45500,
      retailStock: 38,
      wholesaleEligible: true,
      wholesalePriceCents: 1120000,
      wholesaleStock: 25
    },
    {
      slug: "harrar-longberry",
      name: "Harrar Longberry",
      origin: "Harrar",
      process: "Natural",
      roast: "Medium",
      description:
        "Wild eastern highland coffee with a mocha-jungle character, traditionally dry-processed and full of personality.",
      tastingNotes: "Mocha, wild berry, spice",
      hue: 15,
      featured: false,
      retailPriceCents: 39000,
      retailStock: 27,
      wholesaleEligible: true,
      wholesalePriceCents: 980000,
      wholesaleStock: 18
    },
    {
      slug: "limu-washed",
      name: "Limu Washed",
      origin: "Limmu Kosa",
      process: "Washed",
      roast: "Medium",
      description:
        "Balanced and rounded with citrus brightness and a sweet nutty finish, a dependable daily cup.",
      tastingNotes: "Orange, walnut, brown sugar",
      hue: 60,
      featured: false,
      retailPriceCents: 36000,
      retailStock: 8,
      wholesaleEligible: true,
      wholesalePriceCents: 900000,
      wholesaleStock: 12
    },
    {
      slug: "kaffa-wild-forest",
      name: "Kaffa Wild Forest",
      origin: "Kaffa",
      process: "Natural",
      roast: "Medium-dark",
      description:
        "Harvested from semi-wild forest coffee trees in coffee's birthplace. Deep, herbal and wine-dark.",
      tastingNotes: "Dark cherry, cedar, wine",
      hue: 10,
      featured: true,
      retailPriceCents: 52000,
      retailStock: 19,
      wholesaleEligible: true,
      wholesalePriceCents: 1380000,
      wholesaleStock: 9
    },
    {
      slug: "teppi-geisha-lot",
      name: "Teppi Geisha Lot",
      origin: "Maji, Teppi",
      process: "Washed",
      roast: "Light",
      description:
        "A small geisha-variety lot from the far western highlands. Floral, delicate and strictly limited.",
      tastingNotes: "Rose, bergamot, nectarine",
      hue: 80,
      featured: false,
      retailPriceCents: 98000,
      retailStock: 6,
      wholesaleEligible: true,
      wholesalePriceCents: 2900000,
      wholesaleStock: 5
    },
    {
      slug: "addis-espresso-blend",
      name: "Addis Espresso Blend",
      origin: "House blend",
      process: "Blend",
      roast: "Dark",
      description:
        "Our roastery blend built for milk: chocolate-forward Harrar base with Sidama sweetness.",
      tastingNotes: "Dark chocolate, toffee, plum",
      hue: 22,
      featured: false,
      retailPriceCents: 34000,
      retailStock: 64,
      wholesaleEligible: false,
      wholesalePriceCents: 0,
      wholesaleStock: 0
    }
  ];

  for (const p of products) {
    await prisma.product.create({ data: p });
  }
  console.log("Products created: " + products.length);

  // Demo order 1: retail order, currently roasting.
  const o1 = await prisma.order.create({
    data: {
      orderNo: "KO-A1B2C3",
      userId: demo.id,
      buyerType: "retail",
      status: "roasting",
      name: "Daniel Tadesse",
      email: "daniel@kaffaorigins.et",
      phone: "+251 91 234 5678",
      city: "Addis Ababa",
      addressLine: "Bole Road, Rose Building 4th floor",
      subtotalCents: 48000 + 42500,
      shippingCents: 25000,
      totalCents: 48000 + 42500 + 25000,
      items: {
        create: [
          {
            productId: (await prisma.product.findUniqueOrThrow({ where: { slug: "yirgacheffe-washed" } })).id,
            productName: "Yirgacheffe Washed",
            priceType: "retail",
            unitPriceCents: 48000,
            qty: 1,
            lineTotalCents: 48000
          },
          {
            productId: (await prisma.product.findUniqueOrThrow({ where: { slug: "sidama-natural" } })).id,
            productName: "Sidama Natural",
            priceType: "retail",
            unitPriceCents: 42500,
            qty: 1,
            lineTotalCents: 42500
          }
        ]
      }
    }
  });
  await prisma.orderEvent.createMany({
    data: [
      {
        orderId: o1.id,
        status: "placed",
        message: "We received your order and sent this confirmation.",
        createdAt: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000)
      },
      {
        orderId: o1.id,
        status: "confirmed",
        message: "Payment window confirmed. Your order is in the roasting queue.",
        createdAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000)
      },
      {
        orderId: o1.id,
        status: "roasting",
        message: "Your coffee is roasting now. Freshness is everything - we ship within 24 hours of roast.",
        createdAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000)
      }
    ]
  });

  // Demo order 2: wholesale order, shipped.
  const o2 = await prisma.order.create({
    data: {
      orderNo: "KO-D4E5F6",
      userId: demo.id,
      buyerType: "wholesale",
      status: "shipped",
      name: "Daniel Tadesse",
      email: "daniel@kaffaorigins.et",
      phone: "+251 91 234 5678",
      city: "Dubai",
      addressLine: "JAFZA Warehouse 14, Unit 209",
      subtotalCents: 1250000 * 6,
      shippingCents: 450000,
      totalCents: 1250000 * 6 + 450000,
      items: {
        create: {
          productId: (await prisma.product.findUniqueOrThrow({ where: { slug: "yirgacheffe-washed" } })).id,
          productName: "Yirgacheffe Washed",
          priceType: "wholesale",
          unitPriceCents: 1250000,
          qty: 6,
          lineTotalCents: 1250000 * 6
        }
      }
    }
  });
  await prisma.orderEvent.createMany({
    data: [
      {
        orderId: o2.id,
        status: "placed",
        message: "We received your order and sent this confirmation.",
        createdAt: new Date(Date.now() - 12 * 24 * 60 * 60 * 1000)
      },
      {
        orderId: o2.id,
        status: "confirmed",
        message: "Export paperwork in progress. We will confirm the freight forwarder shortly.",
        createdAt: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000)
      },
      {
        orderId: o2.id,
        status: "shipped",
        message: "Your 6 bags left Addis Ababa Bole International with Ethiopian Cargo. ETA 5 days.",
        createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)
      }
    ]
  });

  console.log("Demo orders created.");
  console.log("Seed complete. Sign in as daniel@kaffaorigins.et / demo-pass-2026 or admin@kaffaorigins.et / admin-pass-2026");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
KO_EOF
cat > "README.md" <<'KO_EOF'
# Kaffa Origins

Fictional Ethiopian coffee exporter storefront: single-origin retail bags plus
wholesale 60kg export lots, with a full demo checkout, order tracking and an
admin back office. Built for a security-first full-stack portfolio.

Stack: Next.js 14 (App Router), TypeScript, Prisma + SQLite, zero UI libraries.

## Quick start

Run from this folder:

    npm install
    cp .env.example .env
    npx prisma db push
    npm run db:seed
    npm run dev

Open http://localhost:3000.

IMPORTANT: after copying .env.example, open .env and set SESSION_SECRET to a
long random string, and make sure DATABASE_URL is present (file:./dev.db).

## Demo accounts

  - Customer: daniel@kaffaorigins.et / demo-pass-2026
  - Admin:    admin@kaffaorigins.et / admin-pass-2026
  - Extra customer: sara@example.com / customer-pass-2026

## How the shop works

  - Retail mode: 250g roasted bags, flat ETB 250 shipping, free over ETB 1,500.
  - Wholesale mode: 60kg green bags, minimum 5 bags per line, flat ETB 4,500
    freight per order. Only wholesale-eligible products are shown.
  - The cart lives in localStorage but only stores slug + qty + price type.
    Every displayed price and total is recomputed server-side.

## Order flow

  1. Customer adds items, reviews the priced cart, and checks out with a
     delivery address.
  2. Checkout decrements stock and creates the order atomically in one
     database transaction; any failure rolls everything back.
  3. The order appears in the customer's Orders page with a timeline of
     email-style updates ("placed", "confirmed", "roasting", "shipped",
     "delivered", "cancelled").
  4. Admins review orders under /admin, change status, and every change is
     written to the timeline the customer sees.

## Security notes

  - Prices and stock are never trusted from the client: /api/cart and
    /api/checkout recompute everything from the database.
  - Stock is re-checked and decremented inside the checkout transaction to
    prevent overselling under concurrent requests.
  - Passwords are hashed with scrypt + per-user salt; sessions are
    HMAC-signed httpOnly cookies (8 hours) with constant-time verification.
  - Login is rate limited (5 failures per 15 minutes per email).
  - Admin routes and APIs verify the session role server-side; customer order
    pages enforce ownership (a customer cannot open another user's order).
  - No-store headers are applied to /orders, /checkout and /admin so the back
    button never exposes private pages after logout.

## Project structure

  app/                     pages (landing, shop, product, cart, checkout,
                           orders, admin) and API routes
  components/              header, footer, product card, pager, theme toggle
  lib/                     prisma client, auth, pricing, money helpers,
                           client-safe cart storage, order status copy
  prisma/schema.prisma     User, Product, Order, OrderItem, OrderEvent
  prisma/seed.ts           demo users, catalog and two demo orders

Fictional business. No real payments, no real fulfillment.
KO_EOF
cat > "tsconfig.json" <<'KO_EOF'
{
  "compilerOptions": {
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
KO_EOF
echo ""
echo "Kaffa Origins project created (v5). Next steps (run INSIDE this kaffa-origins folder):"
echo "  npm install"
echo "  cp .env.example .env   (then set SESSION_SECRET in .env)"
echo "  npx prisma db push"
echo "  npm run db:seed"
echo "  npm run dev"
echo ""
echo "Demo accounts:"
echo "  customer: daniel@kaffaorigins.et / demo-pass-2026"
echo "  admin:    admin@kaffaorigins.et / admin-pass-2026"