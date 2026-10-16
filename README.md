# Kaffa Origins

Fictional Ethiopian coffee exporter storefront: single-origin retail bags plus
wholesale 60kg export lots, with a full demo checkout, order tracking and an
admin back office. Built for a security-first full-stack portfolio.

Stack: Next.js 14 (App Router), TypeScript, Prisma + SQLite, zero UI libraries.

## Quick start

Run from this folder:

    npm install
    cp .env.example .env
    npx prisma db push
    npm run db:seed
    npm run dev

Open http://localhost:3000.

IMPORTANT: after copying .env.example, open .env and set SESSION_SECRET to a
long random string, and make sure DATABASE_URL is present (file:./dev.db).

## Demo accounts

  - Customer: daniel@kaffaorigins.et / demo-pass-2026
  - Admin:    admin@kaffaorigins.et / admin-pass-2026
  - Extra customer: sara@example.com / customer-pass-2026

## How the shop works

  - Retail mode: 250g roasted bags, flat ETB 250 shipping, free over ETB 1,500.
  - Wholesale mode: 60kg green bags, minimum 5 bags per line, flat ETB 4,500
    freight per order. Only wholesale-eligible products are shown.
  - The cart lives in localStorage but only stores slug + qty + price type.
    Every displayed price and total is recomputed server-side.

## Order flow

  1. Customer adds items, reviews the priced cart, and checks out with a
     delivery address.
  2. Checkout decrements stock and creates the order atomically in one
     database transaction; any failure rolls everything back.
  3. The order appears in the customer's Orders page with a timeline of
     email-style updates ("placed", "confirmed", "roasting", "shipped",
     "delivered", "cancelled").
  4. Admins review orders under /admin, change status, and every change is
     written to the timeline the customer sees.

## Security notes

  - Prices and stock are never trusted from the client: /api/cart and
    /api/checkout recompute everything from the database.
  - Stock is re-checked and decremented inside the checkout transaction to
    prevent overselling under concurrent requests.
  - Passwords are hashed with scrypt + per-user salt; sessions are
    HMAC-signed httpOnly cookies (8 hours) with constant-time verification.
  - Login is rate limited (5 failures per 15 minutes per email).
  - Admin routes and APIs verify the session role server-side; customer order
    pages enforce ownership (a customer cannot open another user's order).
  - No-store headers are applied to /orders, /checkout and /admin so the back
    button never exposes private pages after logout.

## Project structure

  app/                     pages (landing, shop, product, cart, checkout,
                           orders, admin) and API routes
  components/              header, footer, product card, pager, theme toggle
  lib/                     prisma client, auth, pricing, money helpers,
                           client-safe cart storage, order status copy
  prisma/schema.prisma     User, Product, Order, OrderItem, OrderEvent
  prisma/seed.ts           demo users, catalog and two demo orders

Fictional business. No real payments, no real fulfillment.
