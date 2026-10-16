import Link from "next/link";
import { prisma } from "../lib/prisma";
import ProductCard from "../components/ProductCard";

async function getFeatured() {
  try {
    return await prisma.product.findMany({
      where: { featured: true, active: true },
      orderBy: { name: "asc" },
      take: 3
    });
  } catch {
    return [];
  }
}

function HeroArt() {
  return (
    <svg viewBox="0 0 200 200" width="100%" aria-hidden="true">
      <ellipse cx="100" cy="100" rx="52" ry="72" transform="rotate(-24 100 100)" fill="#8a4a2b" />
      <ellipse cx="100" cy="100" rx="52" ry="72" transform="rotate(-24 100 100)" fill="url(#beanShade)" />
      <path d="M100 28c-18 24-18 40 0 72s18 48 0 72" fill="none" stroke="#faf6ef" strokeWidth="5" transform="rotate(-24 100 100)" />
      <defs>
        <radialGradient id="beanShade" cx="35%" cy="30%">
          <stop offset="0%" stopColor="#c97a4f" stopOpacity="0.9" />
          <stop offset="100%" stopColor="#5a3020" stopOpacity="0.9" />
        </radialGradient>
      </defs>
    </svg>
  );
}

export default async function LandingPage() {
  const featured = await getFeatured();

  return (
    <>
      <section className="hero">
        <div className="wrap hero-grid">
          <div className="hero-copy">
            <div className="hero-kicker">From the birthplace of coffee</div>
            <h1>Single-origin Ethiopian coffee, shipped from Addis Ababa.</h1>
            <p className="sub">
              Kaffa Origins works directly with washing stations and smallholder farmers across
              Ethiopia&apos;s famous growing regions. Buy roasted 250g bags as a retail customer,
              or full 60kg export lots at wholesale pricing.
            </p>
            <div className="hero-actions">
              <Link href="/shop?mode=retail" className="btn">Shop retail</Link>
              <Link href="/shop?mode=wholesale" className="btn ghost">Wholesale lots</Link>
            </div>
          </div>
          <div className="hero-art">
            <HeroArt />
          </div>
        </div>
      </section>

      <section className="section">
        <div className="wrap">
          <div className="section-head">
            <h2>Featured coffees</h2>
            <Link href="/shop" className="sub">Browse the full catalog -></Link>
          </div>
          {featured.length === 0 ? (
            <p className="empty">No products yet. Run the database seed to load the catalog.</p>
          ) : (
            <div className="prod-grid">
              {featured.map((p) => (
                <ProductCard key={p.id} p={p} mode="retail" />
              ))}
            </div>
          )}
        </div>
      </section>

      <section className="section">
        <div className="wrap grid-2">
          <div>
            <h2>Our story</h2>
            <p className="sub">
              Coffee was born in the forests of Kaffa, in southwestern Ethiopia. We take our name
              from that forest. Every lot we sell is traceable to a single washing station or
              cooperative, cupped at our Addis Ababa roastery, and shipped within days of roast
              (retail) or within weeks of processing (wholesale green).
            </p>
          </div>
          <div>
            <h2>Buying wholesale</h2>
            <p className="sub">
              Wholesale orders are priced per 60kg bag of green coffee with a minimum of 5 bags per
              lot line and a flat ETB 4,500 freight charge. Retail orders ship free over ETB 1,500
              (otherwise a flat ETB 250). Switch between the two anytime from the Shop page.
            </p>
          </div>
        </div>
      </section>
    </>
  );
}
