"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { ORDER_STATUSES, ORDER_STATUS_LABELS, STATUS_MESSAGES } from "../../../../lib/orderStatus";

export default function StatusForm({ orderNo, current }: { orderNo: string; current: string }) {
  const router = useRouter();
  const [status, setStatus] = useState(current);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const res = await fetch("/api/admin/orders", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ orderNo, status })
      });
      const data = await res.json();
      if (res.ok && data.ok) {
        router.refresh();
        return;
      }
      setError(data.error || "Could not update the order.");
    } catch {
      setError("Network error. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="form-stack" onSubmit={submit}>
      <div>
        <label htmlFor="status">New status</label>
        <select id="status" value={status} onChange={(e) => setStatus(e.target.value)}>
          {ORDER_STATUSES.map((s) => (
            <option key={s} value={s}>{ORDER_STATUS_LABELS[s]}</option>
          ))}
        </select>
      </div>
      <p className="sub">The customer will see: {STATUS_MESSAGES[status]}</p>
      {error ? <p className="error-text">{error}</p> : null}
      <button type="submit" className="btn" disabled={busy || status === current}>
        {busy ? "Saving..." : "Save status"}
      </button>
    </form>
  );
}
