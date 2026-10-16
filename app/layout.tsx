import type { Metadata } from "next";
import "./globals.css";
import SiteHeader from "../components/SiteHeader";
import SiteFooter from "../components/SiteFooter";
import { getSession } from "../lib/auth";

export const metadata: Metadata = {
  title: "Kaffa Origins - Ethiopian Coffee Exporter",
  description:
    "Single-origin Ethiopian coffee from Kaffa, Yirgacheffe, Sidama and beyond. Retail roasted bags and wholesale 60kg export lots."
};

// Sets the theme class before first paint to avoid a flash.
const themeInit = `try{if(localStorage.getItem("kaffa-theme")==="dark"||(localStorage.getItem("kaffa-theme")===null&&window.matchMedia("(prefers-color-scheme: dark)").matches)){document.documentElement.classList.add("dark")}}catch(e){}`;

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const session = await getSession();
  return (
    <html lang="en">
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeInit }} />
      </head>
      <body>
        <SiteHeader
          isAdmin={session?.role === "admin"}
          signedIn={Boolean(session)}
        />
        <main>{children}</main>
        <SiteFooter />
      </body>
    </html>
  );
}
