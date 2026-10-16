import { Suspense } from "react";
import LoginForm from "./LoginForm";

export const metadata = { title: "Sign in - Kaffa Origins" };

export default function LoginPage() {
  return (
    <div className="wrap section">
      <h1 style={{ textAlign: "center", marginBottom: 24 }}>Welcome back</h1>
      <Suspense fallback={<p className="empty">Loading...</p>}>
        <LoginForm />
      </Suspense>
    </div>
  );
}
