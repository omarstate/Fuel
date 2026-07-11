import { Navigate } from "react-router-dom"
import { useAuth } from "@/lib/auth"

export function RequireAuth({ children }: { children: React.ReactNode }) {
  const { session, loading } = useAuth()

  if (loading) {
    return (
      <div
        className="flex min-h-screen items-center justify-center"
        style={{ backgroundColor: "#f7f3ea", color: "#6f6a5c" }}
      >
        <span className="font-mono text-xs uppercase tracking-[0.18em]">Loading…</span>
      </div>
    )
  }

  if (!session) return <Navigate to="/login" replace />

  return <>{children}</>
}
