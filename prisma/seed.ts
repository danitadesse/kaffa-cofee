import { PrismaClient } from "@prisma/client";
import { randomBytes, scryptSync } from "crypto";

const prisma = new PrismaClient();

function hash(password: string): string {
  const salt = randomBytes(16).toString("hex");
  return salt + ":" + scryptSync(password, salt, 64).toString("hex");
}

async function main() {
  console.log("Seeding Kaffa Origins demo data...");

  await prisma.orderEvent.deleteMany();
  await prisma.orderItem.deleteMany();
  await prisma.order.deleteMany();
  await prisma.product.deleteMany();
  await prisma.user.deleteMany();

  const admin = await prisma.user.create({
    data: {
      email: "admin@kaffaorigins.et",
      name: "Roastery Admin",
      passwordHash: hash("admin-pass-2026"),
      role: "admin"
    }
  });
  const demo = await prisma.user.create({
    data: {
      email: "daniel@kaffaorigins.et",
      name: "Daniel Tadesse",
      passwordHash: hash("demo-pass-2026"),
      role: "customer"
    }
  });
  await prisma.user.create({
    data: {
      email: "sara@example.com",
      name: "Sara Bekele",
      passwordHash: hash("customer-pass-2026"),
      role: "customer"
    }
  });
  console.log("Users created.");

  // Retail prices are per 250g roasted bag, wholesale per 60kg green bag.
  const products = [
    {
      slug: "yirgacheffe-washed",
      name: "Yirgacheffe Washed",
      origin: "Gedeo, Yirgacheffe",
      process: "Washed",
      roast: "Light",
      description:
        "The classic southern Ethiopian cup: jasmine in the aroma, bright bergamot acidity and a clean tea-like finish.",
      tastingNotes: "Jasmine, bergamot, black tea",
      hue: 28,
      featured: true,
      retailPriceCents: 48000,
      retailStock: 42,
      wholesaleEligible: true,
      wholesalePriceCents: 1250000,
      wholesaleStock: 30
    },
    {
      slug: "sidama-natural",
      name: "Sidama Natural",
      origin: "Sidama",
      process: "Natural",
      roast: "Medium",
      description:
        "Sun-dried on raised beds, bursting with berry sweetness and a heavy chocolate body that shines in espresso.",
      tastingNotes: "Strawberry, blueberry, cocoa",
      hue: 350,
      featured: true,
      retailPriceCents: 42500,
      retailStock: 55,
      wholesaleEligible: true,
      wholesalePriceCents: 1050000,
      wholesaleStock: 40
    },
    {
      slug: "guji-hambela",
      name: "Guji Hambela",
      origin: "Guji",
      process: "Washed",
      roast: "Light",
      description:
        "A highland washed lot with stone fruit sweetness, floral lift and a syrupy mouthfeel.",
      tastingNotes: "Peach, apricot, honey",
      hue: 45,
      featured: true,
      retailPriceCents: 45500,
      retailStock: 38,
      wholesaleEligible: true,
      wholesalePriceCents: 1120000,
      wholesaleStock: 25
    },
    {
      slug: "harrar-longberry",
      name: "Harrar Longberry",
      origin: "Harrar",
      process: "Natural",
      roast: "Medium",
      description:
        "Wild eastern highland coffee with a mocha-jungle character, traditionally dry-processed and full of personality.",
      tastingNotes: "Mocha, wild berry, spice",
      hue: 15,
      featured: false,
      retailPriceCents: 39000,
      retailStock: 27,
      wholesaleEligible: true,
      wholesalePriceCents: 980000,
      wholesaleStock: 18
    },
    {
      slug: "limu-washed",
      name: "Limu Washed",
      origin: "Limmu Kosa",
      process: "Washed",
      roast: "Medium",
      description:
        "Balanced and rounded with citrus brightness and a sweet nutty finish, a dependable daily cup.",
      tastingNotes: "Orange, walnut, brown sugar",
      hue: 60,
      featured: false,
      retailPriceCents: 36000,
      retailStock: 8,
      wholesaleEligible: true,
      wholesalePriceCents: 900000,
      wholesaleStock: 12
    },
    {
      slug: "kaffa-wild-forest",
      name: "Kaffa Wild Forest",
      origin: "Kaffa",
      process: "Natural",
      roast: "Medium-dark",
      description:
        "Harvested from semi-wild forest coffee trees in coffee's birthplace. Deep, herbal and wine-dark.",
      tastingNotes: "Dark cherry, cedar, wine",
      hue: 10,
      featured: true,
      retailPriceCents: 52000,
      retailStock: 19,
      wholesaleEligible: true,
      wholesalePriceCents: 1380000,
      wholesaleStock: 9
    },
    {
      slug: "teppi-geisha-lot",
      name: "Teppi Geisha Lot",
      origin: "Maji, Teppi",
      process: "Washed",
      roast: "Light",
      description:
        "A small geisha-variety lot from the far western highlands. Floral, delicate and strictly limited.",
      tastingNotes: "Rose, bergamot, nectarine",
      hue: 80,
      featured: false,
      retailPriceCents: 98000,
      retailStock: 6,
      wholesaleEligible: true,
      wholesalePriceCents: 2900000,
      wholesaleStock: 5
    },
    {
      slug: "addis-espresso-blend",
      name: "Addis Espresso Blend",
      origin: "House blend",
      process: "Blend",
      roast: "Dark",
      description:
        "Our roastery blend built for milk: chocolate-forward Harrar base with Sidama sweetness.",
      tastingNotes: "Dark chocolate, toffee, plum",
      hue: 22,
      featured: false,
      retailPriceCents: 34000,
      retailStock: 64,
      wholesaleEligible: false,
      wholesalePriceCents: 0,
      wholesaleStock: 0
    }
  ];

  for (const p of products) {
    await prisma.product.create({ data: p });
  }
  console.log("Products created: " + products.length);

  // Demo order 1: retail order, currently roasting.
  const o1 = await prisma.order.create({
    data: {
      orderNo: "KO-A1B2C3",
      userId: demo.id,
      buyerType: "retail",
      status: "roasting",
      name: "Daniel Tadesse",
      email: "daniel@kaffaorigins.et",
      phone: "+251 91 234 5678",
      city: "Addis Ababa",
      addressLine: "Bole Road, Rose Building 4th floor",
      subtotalCents: 48000 + 42500,
      shippingCents: 25000,
      totalCents: 48000 + 42500 + 25000,
      items: {
        create: [
          {
            productId: (await prisma.product.findUniqueOrThrow({ where: { slug: "yirgacheffe-washed" } })).id,
            productName: "Yirgacheffe Washed",
            priceType: "retail",
            unitPriceCents: 48000,
            qty: 1,
            lineTotalCents: 48000
          },
          {
            productId: (await prisma.product.findUniqueOrThrow({ where: { slug: "sidama-natural" } })).id,
            productName: "Sidama Natural",
            priceType: "retail",
            unitPriceCents: 42500,
            qty: 1,
            lineTotalCents: 42500
          }
        ]
      }
    }
  });
  await prisma.orderEvent.createMany({
    data: [
      {
        orderId: o1.id,
        status: "placed",
        message: "We received your order and sent this confirmation.",
        createdAt: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000)
      },
      {
        orderId: o1.id,
        status: "confirmed",
        message: "Payment window confirmed. Your order is in the roasting queue.",
        createdAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000)
      },
      {
        orderId: o1.id,
        status: "roasting",
        message: "Your coffee is roasting now. Freshness is everything - we ship within 24 hours of roast.",
        createdAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000)
      }
    ]
  });

  // Demo order 2: wholesale order, shipped.
  const o2 = await prisma.order.create({
    data: {
      orderNo: "KO-D4E5F6",
      userId: demo.id,
      buyerType: "wholesale",
      status: "shipped",
      name: "Daniel Tadesse",
      email: "daniel@kaffaorigins.et",
      phone: "+251 91 234 5678",
      city: "Dubai",
      addressLine: "JAFZA Warehouse 14, Unit 209",
      subtotalCents: 1250000 * 6,
      shippingCents: 450000,
      totalCents: 1250000 * 6 + 450000,
      items: {
        create: {
          productId: (await prisma.product.findUniqueOrThrow({ where: { slug: "yirgacheffe-washed" } })).id,
          productName: "Yirgacheffe Washed",
          priceType: "wholesale",
          unitPriceCents: 1250000,
          qty: 6,
          lineTotalCents: 1250000 * 6
        }
      }
    }
  });
  await prisma.orderEvent.createMany({
    data: [
      {
        orderId: o2.id,
        status: "placed",
        message: "We received your order and sent this confirmation.",
        createdAt: new Date(Date.now() - 12 * 24 * 60 * 60 * 1000)
      },
      {
        orderId: o2.id,
        status: "confirmed",
        message: "Export paperwork in progress. We will confirm the freight forwarder shortly.",
        createdAt: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000)
      },
      {
        orderId: o2.id,
        status: "shipped",
        message: "Your 6 bags left Addis Ababa Bole International with Ethiopian Cargo. ETA 5 days.",
        createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)
      }
    ]
  });

  console.log("Demo orders created.");
  console.log("Seed complete. Sign in as daniel@kaffaorigins.et / demo-pass-2026 or admin@kaffaorigins.et / admin-pass-2026");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
