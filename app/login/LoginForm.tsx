"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";

export default function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get("next") || "/orders";
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password })
      });
      const data = await res.json();
      if (res.ok && data.ok) {
        router.push(next);
        router.refresh();
        return;
      }
      setError(data.error || "Could not sign you in.");
    } catch {
      setError("Network error. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="panel" style={{ maxWidth: 440, margin: "0 auto" }}>
      <div className="panel-head"><h2>Sign in</h2></div>
      <div className="panel-body">
        <form className="form-stack" onSubmit={submit}>
          <div>
            <label htmlFor="email">Email</label>
            <input
              id="email"
              type="email"
              className="wide-field"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoComplete="email"
            />
          </div>
          <div>
            <label htmlFor="password">Password</label>
            <input
              id="password"
              type="password"
              className="wide-field"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              autoComplete="current-password"
            />
          </div>
          {error ? <p className="error-text">{error}</p> : null}
          <button type="submit" className="btn wide" disabled={busy}>
            {busy ? "Signing in..." : "Sign in"}
          </button>
        </form>
        <p className="sub" style={{ marginTop: 14 }}>
          No account yet? <Link href="/signup">Create one</Link>.
        </p>
      </div>
    </div>
  );
}
