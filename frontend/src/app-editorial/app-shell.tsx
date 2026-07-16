import * as React from "react"
import { Link, Outlet, useLocation } from "react-router-dom"
import { Menu } from "lucide-react"
import { ModeProvider, useMode } from "@/components/site/mode-context"
import { SidebarInset, SidebarProvider, useSidebar } from "@/components/ui/sidebar"
import { AppSidebar } from "@/app-editorial/app-sidebar"
import { LogoMark } from "@/app-editorial/logo-mark"
import { editorialAccent, editorialAccentInk, editorialSpark } from "@/app-editorial/theme"
import { MeProvider } from "@/app-editorial/use-me"
import { OnboardingDialog } from "@/app-editorial/onboarding-dialog"

/** Mobile-only top bar: hamburger opens the sidebar sheet + brand. Hidden on md+. */
function MobileTopBar() {
  const { toggleSidebar } = useSidebar()
  const { mode } = useMode()
  return (
    <header className="sticky top-0 z-30 flex items-center gap-3 border-b border-border bg-background/90 px-4 py-2.5 backdrop-blur-md md:hidden">
      <button
        type="button"
        onClick={toggleSidebar}
        aria-label="Open navigation"
        className="grid size-10 shrink-0 place-items-center rounded-lg border border-border bg-card text-foreground transition-transform active:scale-95"
      >
        <Menu className="size-5" />
      </button>
      <Link to="/dashboard" className="flex items-center gap-2">
        <LogoMark
          className="size-6"
          accent={editorialAccent[mode]}
          spark={editorialSpark[mode]}
        />
        <span className="font-heading text-lg font-semibold tracking-tight text-foreground">
          Fuel
        </span>
      </Link>
    </header>
  )
}

function AppShellInner() {
  const location = useLocation()
  const { mode, setMode } = useMode()

  // Opt this route tree into the light editorial theme. The class lives on
  // <html> so portaled UI (dialogs, selects, toasts) inherits the tokens too.
  React.useEffect(() => {
    const root = document.documentElement
    root.classList.add("theme-fuel-light")
    return () => root.classList.remove("theme-fuel-light")
  }, [])

  React.useEffect(() => {
    setMode(location.pathname.startsWith("/dashboard/workouts") ? "workouts" : "nutrition")
  }, [location.pathname, setMode])

  const accent = editorialAccent[mode]
  const themeVars = {
    "--primary": accent,
    "--primary-foreground": "#14120f",
    "--ring": accent,
    "--accent-ink": editorialAccentInk[mode],
    "--accent-tint": `${accent}24`,
    "--sidebar-primary": accent,
    "--sidebar-primary-foreground": "#14120f",
    "--sidebar-ring": accent,
    "--sidebar-accent": `color-mix(in oklab, ${accent} 14%, #fffdf7)`,
    "--sidebar-accent-foreground": "#14120f",
  } as React.CSSProperties

  return (
    <SidebarProvider style={themeVars}>
      <AppSidebar />
      <SidebarInset className="bg-background">
        <MobileTopBar />
        <div className="px-4 py-5 sm:px-8 sm:py-8 lg:px-10">
          <MeProvider>
            <Outlet />
            <OnboardingDialog />
          </MeProvider>
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}

export function AppShellEditorial() {
  return (
    <ModeProvider>
      <AppShellInner />
    </ModeProvider>
  )
}

export default AppShellEditorial
