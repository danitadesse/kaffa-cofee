import { NextRequest, NextResponse } from "next/server";

// Authenticated areas are never cached, so the browser back button can
// never reveal an order page or the admin console after logout.
export function middleware(req: NextRequest) {
  const res = NextResponse.next();
  res.headers.set("Cache-Control", "no-store, must-revalidate");
  return res;
}

export const config = {
  matcher: ["/orders/:path*", "/admin/:path*", "/checkout/:path*"]
};
