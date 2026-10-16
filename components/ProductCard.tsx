import Link from "next/link";
import { etb } from "../lib/money";

type CardProduct = {
  slug: string;
  name: string;
  origin: string;
  process: string;
  roast: string;
  hue: number;
  retailPriceCents: number;
  retailStock: number;
  wholesaleEligible: boolean;
  wholesalePriceCents: number;
  wholesaleStock: number;
};

// Server component. Renders gradient art derived from the product hue
// so the catalog looks designed without shipping any binary images.
export default function ProductCard({ p, mode }: { p: CardProduct; mode: string }) {
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
    <Link href={"/product/" + p.slug + (wholesale ? "?mode=wholesale" : "")} className="prod-card">
      <div
        className="prod-art"
        style={{ background: "linear-gradient(135deg, hsl(" + p.hue + ", 45%, 55%), hsl(" + ((p.hue + 40) % 360) + ", 50%, 38%))" }}
      >
        <span className="initials">{initials}</span>
        <span className="prod-meta-chips">
          <span className="chip neutral">{p.roast}</span>
          <span className="chip neutral">{p.process}</span>
        </span>
      </div>
      <div className="prod-body">
        <span className="prod-name">{p.name}</span>
        <span className="prod-origin">{p.origin}</span>
        <span className="prod-foot">
          <span className="price">
            {etb(price)}
            <span className="unit"> / {wholesale ? "60kg bag" : "250g"}</span>
          </span>
          <span className={"chip " + (stock > 0 ? "ok" : "bad")}>
            {stock > 0 ? stock + " in stock" : "Out of stock"}
          </span>
        </span>
      </div>
    </Link>
  );
}
