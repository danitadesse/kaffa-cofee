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
