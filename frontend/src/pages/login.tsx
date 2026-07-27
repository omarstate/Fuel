import * as React from "react"
import { Link, useNavigate } from "react-router-dom"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { LanguageToggle } from "@/components/language-toggle"
import { LogoMark } from "@/components/site/logo-mark"
import { useAuth } from "@/lib/auth"
import { useI18n } from "@/lib/i18n"
import { isSupabaseConfigured } from "@/lib/supabase"

export function LoginPage() {
  const navigate = useNavigate()
  const { t } = useI18n()
  const { session, signInWithPassword, signUp } = useAuth()
  const [mode, setMode] = React.useState<"signin" | "signup">("signin")
  const [email, setEmail] = React.useState("")
  const [password, setPassword] = React.useState("")
  const [error, setError] = React.useState<string | null>(null)
  const [busy, setBusy] = React.useState(false)

  React.useEffect(() => {
    if (session) navigate("/dashboard", { replace: true })
  }, [session, navigate])

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    if (!isSupabaseConfigured) {
      setError(t("login.supabaseMissingInline"))
      return
    }
    setBusy(true)
    try {
      if (mode === "signin") {
        const { error } = await signInWithPassword(email, password)
        if (error) return setError(error)
        navigate("/dashboard", { replace: true })
      } else {
        const { error, needsConfirmation } = await signUp(email, password)
        if (error) return setError(error)
        if (needsConfirmation) {
          toast.success(t("login.accountCreated"))
          setMode("signin")
        } else {
          navigate("/dashboard", { replace: true })
        }
      }
    } finally {
      setBusy(false)
    }
  }

  return (
    <div
      className="theme-fuel-light flex min-h-screen items-center justify-center px-6 font-sans antialiased"
      style={{ backgroundColor: "#f7f3ea", color: "#14120f" }}
    >
      <div className="w-full max-w-sm">
        <div className="mb-8 flex items-center justify-between gap-3">
          <Link to="/" className="flex items-center gap-2.5">
            <LogoMark className="size-8" />
            <span className="font-heading text-2xl font-semibold tracking-tight">Fuel</span>
          </Link>
          <LanguageToggle />
        </div>

        <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[#b5431c]">
          {mode === "signin" ? t("login.welcomeBack") : t("login.getStarted")}
        </div>
        <h1 className="mt-2 font-heading text-3xl font-semibold tracking-tight">
          {mode === "signin" ? t("login.signInTitle") : t("login.signUpTitle")}
        </h1>
        <p className="mt-2 text-sm text-muted-foreground">
          {mode === "signin" ? t("login.signInSubtitle") : t("login.signUpSubtitle")}
        </p>

        {!isSupabaseConfigured && (
          <div className="mt-6 rounded-lg border border-[#e0b23a] bg-[#fbf3db] px-3 py-2.5 text-xs text-[#8a6400]">
            {t("login.supabaseMissingInline")}
          </div>
        )}

        <form onSubmit={handleSubmit} className="mt-7 flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="email">{t("login.email")}</Label>
            <Input
              id="email"
              type="email"
              autoComplete="email"
              placeholder="you@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="password">{t("login.password")}</Label>
            <Input
              id="password"
              type="password"
              autoComplete={mode === "signin" ? "current-password" : "new-password"}
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              minLength={6}
              required
            />
          </div>

          {error && <p className="text-sm text-destructive">{error}</p>}

          <Button
            type="submit"
            disabled={busy}
            className="mt-1 h-10 bg-[#14120f] text-[#f7f3ea] hover:bg-[#2a251d]"
          >
            {busy
              ? t("common.oneSec")
              : mode === "signin"
                ? t("login.signIn")
                : t("login.createAccount")}
          </Button>
        </form>

        <p className="mt-6 text-sm text-muted-foreground">
          {mode === "signin" ? t("login.newToFuel") : t("login.haveAccount")}
          <button
            type="button"
            onClick={() => {
              setMode(mode === "signin" ? "signup" : "signin")
              setError(null)
            }}
            className="font-medium text-[#b5431c] underline-offset-4 hover:underline"
          >
            {mode === "signin" ? t("login.createOne") : t("login.signIn")}
          </button>
        </p>
      </div>
    </div>
  )
}

export default LoginPage
