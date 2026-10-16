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
