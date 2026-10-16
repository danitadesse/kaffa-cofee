import SignupForm from "./SignupForm";

export const metadata = { title: "Create account - Kaffa Origins" };

export default function SignupPage() {
  return (
    <div className="wrap section">
      <h1 style={{ textAlign: "center", marginBottom: 24 }}>Join Kaffa Origins</h1>
      <SignupForm />
    </div>
  );
}
