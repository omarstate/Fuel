import * as React from "react"
import { Outlet, useLocation } from "react-router-dom"
import { ModeProvider, useMode, modeColors } from "@/components/site/mode-context"
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar"
import { AppSidebar } from "@/app/app-sidebar"

function AppShellInner() {
  const location = useLocation()
  const { mode, setMode } = useMode()

  React.useEffect(() => {
    setMode(location.pathname.startsWith("/app/workouts") ? "workouts" : "nutrition")
  }, [location.pathname, setMode])

  const accent = modeColors[mode]
  const themeVars = {
    "--primary": accent,
    "--primary-foreground": "var(--char)",
    "--ring": accent,
    "--sidebar-primary": accent,
    "--sidebar-primary-foreground": "var(--char)",
    "--sidebar-ring": accent,
    "--sidebar-accent": `color-mix(in oklab, ${accent} 18%, var(--char-2))`,
    "--sidebar-accent-foreground": "var(--bone)",
  } as React.CSSProperties

  return (
    <SidebarProvider style={themeVars}>
      <AppSidebar />
      <SidebarInset className="bg-char">
        <div className="min-h-svh px-6 py-8 sm:px-10">
          <Outlet />
        </div>
      </SidebarInset>
    </SidebarProvider>
  )
}

export function AppShell() {
  return (
    <ModeProvider>
      <AppShellInner />
    </ModeProvider>
  )
}
