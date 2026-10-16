// All amounts are stored as integer cents to avoid floating point drift.
// ETB has 2 decimal places in this demo.

export function etb(cents: number): string {
  const n = Number(cents) || 0;
  const sign = n < 0 ? "-" : "";
  const abs = Math.abs(Math.round(n));
  const whole = Math.floor(abs / 100);
  const frac = String(abs % 100).padStart(2, "0");
  return sign + "ETB " + whole.toLocaleString("en-US") + "." + frac;
}

export function toCents(amount: string | number): number | null {
  const n = Number(amount);
  if (!Number.isFinite(n)) return null;
  return Math.round(n * 100);
}

// Minimum bags per wholesale lot line. Kept here because this file is
// client-safe (no node:crypto or prisma imports).
export const WHOLESALE_MOQ = 5;
