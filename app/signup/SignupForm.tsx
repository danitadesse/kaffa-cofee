"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

export default function SignupForm() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    setBusy(true);
    try {
      const res = await fetch("/api/auth/signup", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, email, password })
      });
      const data = await res.json();
      if (res.ok && data.ok) {
        router.push("/shop");
        router.refresh();
        return;
      }
      setError(data.error || "Could not create your account.");
    } catch {
      setError("Network error. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="panel" style={{ maxWidth: 440, margin: "0 auto" }}>
      <div className="panel-head"><h2>Create account</h2></div>
      <div className="panel-body">
        <form className="form-stack" onSubmit={submit}>
          <div>
            <label htmlFor="name">Full name</label>
            <input id="name" className="wide-field" value={name} onChange={(e) => setName(e.target.value)} required maxLength={80} />
          </div>
          <div>
            <label htmlFor="email">Email</label>
            <input id="email" type="email" className="wide-field" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" />
          </div>
          <div>
            <label htmlFor="password">Password (min 8 characters)</label>
            <input id="password" type="password" className="wide-field" value={password} onChange={(e) => setPassword(e.target.value)} required minLength={8} autoComplete="new-password" />
          </div>
          {error ? <p className="error-text">{error}</p> : null}
          <button type="submit" className="btn wide" disabled={busy}>
            {busy ? "Creating..." : "Create account"}
          </button>
        </form>
        <p className="sub" style={{ marginTop: 14 }}>
          Already registered? <Link href="/login">Sign in</Link>.
        </p>
      </div>
    </div>
  );
}
