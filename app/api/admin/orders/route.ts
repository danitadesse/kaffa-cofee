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
