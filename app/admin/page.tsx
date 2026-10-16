import Link from "next/link";
import { prisma } from "../../lib/prisma";
import { etb } from "../../lib/money";
import { ORDER_STATUSES, ORDER_STATUS_LABELS, STATUS_CHIP_CLASS, BUYER_TYPE_LABELS } from "../../lib/orderStatus";

export const metadata = { title: "Admin dashboard - Kaffa Origins" };

export default async function AdminOverviewPage() {
  const [orders, products, recentEvents] = await Promise.all([
    prisma.order.findMany({
      include: { items: true, user: { select: { name: true, email: true } } },
      orderBy: { createdAt: "desc" }
    }),
    prisma.product.findMany({
      where: { active: true },
      select: { name: true, retailStock: true, wholesaleStock: true, wholesaleEligible: true }
    }),
    prisma.orderEvent.findMany({
      orderBy: { createdAt: "desc" },
      take: 6,
      include: { order: { select: { orderNo: true } } }
    })
  ]);

  const live = orders.filter((o) => o.status !== "cancelled");
  const revenue = live.reduce((sum, o) => sum + o.totalCents, 0);
  const retailOrders = orders.filter((o) => o.buyerType === "retail");
  const wholesaleOrders = orders.filter((o) => o.buyerType === "wholesale");
  const avgOrder = live.length > 0 ? Math.round(revenue / live.length) : 0;

  const byStatus: Record<string, number> = {};
  for (const o of orders) byStatus[o.status] = (byStatus[o.status] || 0) + 1;

  const lowStock = products.filter(
    (p) => p.retailStock < 10 || (p.wholesaleEligible && p.wholesaleStock < 10)
  );

  // Revenue for the last 6 months (oldest first) for the bar chart.
  const now = new Date();
  const months: { label: string; key: string; cents: number }[] = [];
  for (let i = 5; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    months.push({
      label: d.toLocaleString("en-US", { month: "short" }) + " " + String(d.getFullYear()).slice(2),
      key: d.getFullYear() + "-" + String(d.getMonth()).padStart(2, "0"),
      cents: 0
    });
  }
  for (const o of live) {
    const k = o.createdAt.getFullYear() + "-" + String(o.createdAt.getMonth()).padStart(2, "0");
    const m = months.find((x) => x.key === k);
    if (m) m.cents += o.totalCents;
  }
  const maxMonth = Math.max(1, ...months.map((m) => m.cents));

  // Top products by units sold across all orders.
  const sold: Record<string, { name: string; units: number; cents: number }> = {};
  for (const o of orders) {
    for (const it of o.items) {
      if (!sold[it.productName]) sold[it.productName] = { name: it.productName, units: 0, cents: 0 };
      sold[it.productName].units += it.qty;
      sold[it.productName].cents += it.lineTotalCents;
    }
  }
  const top = Object.values(sold).sort((a, b) => b.cents - a.cents).slice(0, 5);
  const maxTop = Math.max(1, ...top.map((t) => t.cents));

  const recent = orders.slice(0, 5);

  return (
    <>
      <div className="stat-grid">
        <div className="stat">
          <div className="l">Revenue (excl. cancelled)</div>
          <div className="n">{etb(revenue)}</div>
          <div className="sub">{live.length} live orders - avg {etb(avgOrder)} per order</div>
        </div>
        <div className="stat">
          <div className="l">Retail orders</div>
          <div className="n">{retailOrders.length}</div>
          <div className="sub">{etb(retailOrders.reduce((s, o) => s + o.totalCents, 0))} retail volume</div>
        </div>
        <div className="stat">
          <div className="l">Wholesale orders</div>
          <div className="n">{wholesaleOrders.length}</div>
          <div className="sub">{etb(wholesaleOrders.reduce((s, o) => s + o.totalCents, 0))} wholesale volume</div>
        </div>
      </div>

      <div className="grid-2" style={{ alignItems: "start" }}>
        <div className="panel">
          <div className="panel-head"><h2>Revenue, last 6 months</h2></div>
          <div className="panel-body">
            <div style={{ display: "flex", alignItems: "flex-end", gap: 14, height: 150, padding: "6px 2px 0" }}>
              {months.map((m) => (
                <div key={m.key} style={{ flex: 1, textAlign: "center" }}>
                  <div className="sub" style={{ fontSize: 11.5, marginBottom: 4 }}>
                    {m.cents > 0 ? etb(m.cents) : "-"}
                  </div>
                  <div
                    style={{
                      height: Math.max(4, Math.round((m.cents / maxMonth) * 100)),
                      background: "var(--accent)",
                      borderRadius: "6px 6px 0 0",
                      opacity: m.cents > 0 ? 1 : 0.25
                    }}
                  />
                  <div className="sub" style={{ fontSize: 11.5, marginTop: 6 }}>{m.label}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
        <div className="panel">
          <div className="panel-head"><h2>Top products by revenue</h2></div>
          <div className="panel-body">
            {top.length === 0 ? (
              <p className="empty">No sales recorded yet.</p>
            ) : (
              top.map((t) => (
                <div key={t.name} style={{ marginBottom: 12 }}>
                  <div style={{ display: "flex", justifyContent: "space-between", fontSize: 13.5 }}>
                    <span>{t.name} <span className="sub">({t.units} sold)</span></span>
                    <span className="mono">{etb(t.cents)}</span>
                  </div>
                  <div style={{ height: 8, background: "var(--canvas)", borderRadius: 4, marginTop: 5 }}>
                    <div style={{ width: Math.max(3, Math.round((t.cents / maxTop) * 100)) + "%", height: 8, background: "var(--accent)", borderRadius: 4 }} />
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      <div className="grid-2" style={{ alignItems: "start", marginTop: 18 }}>
        <div className="panel">
          <div className="panel-head">
            <h2>Orders by status</h2>
            <Link href="/admin/orders" className="sub">Manage orders -&gt;</Link>
          </div>
          <div className="panel-body">
            {ORDER_STATUSES.map((s) => (
              <p key={s} className="sub" style={{ display: "flex", justifyContent: "space-between" }}>
                <span>
                  <span className={"chip " + (STATUS_CHIP_CLASS[s] || "neutral")}>{ORDER_STATUS_LABELS[s]}</span>
                </span>
                <span className="mono">{byStatus[s] || 0}</span>
              </p>
            ))}
            {lowStock.length > 0 ? (
              <p className="notice warn" style={{ marginTop: 14 }}>
                {lowStock.length} product(s) low on stock -{" "}
                <Link href="/admin/products">restock now</Link>.
              </p>
            ) : (
              <p className="notice ok" style={{ marginTop: 14 }}>All active products are well stocked.</p>
            )}
          </div>
        </div>
        <div className="panel">
          <div className="panel-head"><h2>Recent orders</h2></div>
          <div className="table-scroll">
            <table className="ko-table">
              <thead>
                <tr>
                  <th>Order</th>
                  <th>Customer</th>
                  <th>Type</th>
                  <th className="num">Total</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {recent.length === 0 ? (
                  <tr><td colSpan={5} className="empty">No orders yet.</td></tr>
                ) : (
                  recent.map((o) => (
                    <tr key={o.id}>
                      <td>
                        <Link href={"/admin/orders/" + o.orderNo} className="mono">{o.orderNo}</Link>
                        <div className="sub">{o.createdAt.toISOString().slice(0, 10)}</div>
                      </td>
                      <td>{o.user.name}<div className="sub">{o.user.email}</div></td>
                      <td>{BUYER_TYPE_LABELS[o.buyerType] || o.buyerType}</td>
                      <td className="num">{etb(o.totalCents)}</td>
                      <td>
                        <span className={"chip " + (STATUS_CHIP_CLASS[o.status] || "neutral")}>
                          {ORDER_STATUS_LABELS[o.status] || o.status}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
          <div className="panel-body">
            <h3 style={{ fontSize: 14 }}>Latest activity</h3>
            {recentEvents.length === 0 ? (
              <p className="sub">No order events yet.</p>
            ) : (
              recentEvents.map((e) => (
                <p key={e.id} className="sub" style={{ marginBottom: 6 }}>
                  <span className="mono">{e.order.orderNo}</span> -{" "}
                  {ORDER_STATUS_LABELS[e.status] || e.status} -{" "}
                  {e.createdAt.toISOString().slice(0, 16).replace("T", " ")}
                </p>
              ))
            )}
          </div>
        </div>
      </div>
    </>
  );
}
