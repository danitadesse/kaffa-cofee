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
        </nav>
      </div>
      {children}
    </div>
  );
}
