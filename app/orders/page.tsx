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
