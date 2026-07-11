import { Button } from "@/components/ui/button"
import { LogoMark } from "@/components/site/logo-mark"

const links = [
  { href: "#pillars", label: "Nutrition & workouts" },
  { href: "#features", label: "How it works" },
  { href: "#stats", label: "Progress" },
]

function scrollTo(id: string) {
  document.querySelector(id)?.scrollIntoView({ behavior: "smooth" })
}

export function Nav() {
  return (
    <header className="sticky top-0 z-50 border-b border-bone/10 bg-char/70 backdrop-blur-lg">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
        <a
          href="#top"
          onClick={(e) => {
            e.preventDefault()
            scrollTo("#top")
          }}
          className="flex items-center gap-2.5"
        >
          <LogoMark className="size-8" />
          <span className="font-heading text-lg font-semibold tracking-tight text-bone">
            Fuel
          </span>
        </a>

        <nav className="hidden items-center gap-8 md:flex">
          {links.map((link) => (
            <a
              key={link.href}
              href={link.href}
              onClick={(e) => {
                e.preventDefault()
                scrollTo(link.href)
              }}
              className="text-sm text-smoke transition-colors hover:text-bone"
            >
              {link.label}
            </a>
          ))}
        </nav>

        <Button onClick={() => scrollTo("#join")}>Start free</Button>
      </div>
    </header>
  )
}
