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
