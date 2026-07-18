import * as React from "react"

export type Mode = "nutrition" | "workouts"

export const modeColors: Record<Mode, string> = {
  nutrition: "#ff6b35",
  workouts: "#d7fa34",
}

const ModeContext = React.createContext<{
  mode: Mode
  setMode: (mode: Mode) => void
} | null>(null)

export function ModeProvider({
  children,
  defaultMode = "nutrition",
}: {
  children: React.ReactNode
  defaultMode?: Mode
}) {
  const [mode, setMode] = React.useState<Mode>(defaultMode)
  return (
    <ModeContext.Provider value={{ mode, setMode }}>
      {children}
    </ModeContext.Provider>
  )
}

export function useMode() {
  const ctx = React.useContext(ModeContext)
  if (!ctx) throw new Error("useMode must be used within ModeProvider")
  return ctx
}
