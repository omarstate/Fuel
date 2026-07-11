import { ModeProvider } from "@/components/site/mode-context"
import { Nav } from "@/components/site/nav"
import { Hero } from "@/components/site/hero"
import { Marquee } from "@/components/site/marquee"
import { Pillars } from "@/components/site/pillars"
import { FeatureBento } from "@/components/site/feature-bento"
import { Stats } from "@/components/site/stats"
import { Cta } from "@/components/site/cta"
import { Footer } from "@/components/site/footer"

export function LandingPage() {
  return (
    <ModeProvider>
      <div className="min-h-svh bg-char text-bone">
        <Nav />
        <main>
          <Hero />
          <Marquee />
          <Pillars />
          <FeatureBento />
          <Stats />
          <Cta />
        </main>
        <Footer />
      </div>
    </ModeProvider>
  )
}
