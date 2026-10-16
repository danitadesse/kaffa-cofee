"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import ThemeToggle from "./ThemeToggle";
import CartBadge from "./CartBadge";

// Brand mark: a coffee bean drawn as an inline SVG (ASCII-safe, no deps).
function BrandMark() {
  return (
    <svg width="26" height="26" viewBox="0 0 24 24" aria-hidden="true">
      <ellipse cx="12" cy="12" rx="9" ry="11" fill="#b35a33" />
      <path
        d="M12 1c-3 4-3 6 0 11s3 7 0 11"
        fill="none"
        stroke="#faf6ef"
        strokeWidth="1.8"
      />
    </svg>
  );
}

type Props = {
  isAdmin: boolean;
  signedIn: boolean;
};

// Customers and guests see the Home / Shop / Orders links. When an admin
// is signed in the header goes minimal: brand, cart, sign out, theme
// toggle only (the admin works from /admin, not the storefront nav).
export default function SiteHeader({ isAdmin, signedIn }: Props) {
  const path = usePathname();
  const on = (href: string) =>
    path === href || (href !== "/" && path.startsWith(href + "/"))
      ? " active"
      : "";

  return (
    <div className="chrome">
      <div className="wrap site-header">
        <Link href="/" className="site-brand">
          <BrandMark />
          <span>Kaffa Origins</span>
        </Link>
        {!isAdmin ? (
          <nav className="main-nav">
            <Link href="/" className={on("/")}>
              Home
            </Link>
            <Link href="/shop" className={on("/shop")}>
              Shop
            </Link>
            <Link href="/orders" className={on("/orders")}>
              Orders
            </Link>
          </nav>
        ) : null}
        <div
          className="chrome-actions"
          style={!isAdmin ? undefined : { marginLeft: "auto" }}
        >
          <CartBadge />
          {signedIn ? (
            <a href="/api/auth/logout" className="btn ghost sm">
              Sign out
            </a>
          ) : (
            <Link href="/login" className="btn ghost sm">
              Sign in
            </Link>
          )}
          <ThemeToggle />
        </div>
      </div>
    </div>
  );
}
