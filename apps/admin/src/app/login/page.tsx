import { LoginForm } from './login-form';

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ expired?: string }> }) {
  const { expired } = await searchParams;
  return (
    <main className="login">
      <h1>Yuz Admin</h1>
      {expired && <p className="message">Your session ended. Sign in again.</p>}
      <LoginForm />
    </main>
  );
}
