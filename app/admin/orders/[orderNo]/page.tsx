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
