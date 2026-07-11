import * as React from "react"
import { Outlet, useLocation } from "react-router-dom"
import { ModeProvider, useMode } from "@/components/site/mode-context"
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar"
import { AppSidebar } from "@/app-editorial/app-sidebar"
import { editorialAccent, editorialAccentInk } from "@/app-editorial/theme"
import { MeProvider } from "@/app-editorial/use-me"

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
        <div className="min-h-svh px-6 py-8 sm:px-10">
          <MeProvider>
            <Outlet />
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
