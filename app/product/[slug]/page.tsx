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
