import { LogoMark } from "@/components/site/logo-mark"

export function Footer() {
  return (
    <footer className="py-10">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 px-6 text-sm text-smoke sm:flex-row">
        <div className="flex items-center gap-2">
          <LogoMark className="size-5" />
          <span className="text-bone/80">Fuel</span>
        </div>
        <p>Built for people who track both sides of the equation.</p>
        <span>&copy; {new Date().getFullYear()} Fuel</span>
      </div>
    </footer>
  )
}
