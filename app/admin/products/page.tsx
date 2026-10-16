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
