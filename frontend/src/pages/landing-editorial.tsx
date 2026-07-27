import { useRef, useState, type ReactElement } from "react"
import { Link } from "react-router-dom"
import { motion } from "framer-motion"
import gsap from "gsap"
import { ScrollTrigger } from "gsap/ScrollTrigger"
import { useGSAP } from "@gsap/react"

import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { RotatingText } from "@/components/site/rotating-text"
import { type Mode } from "@/components/site/mode-context"
import {
  ScreenFrame,
  NutritionPreview,
  WorkoutPreview,
  CoachPreview,
} from "@/app-editorial/previews/screen-previews"
import fuelLogo from "@/assets/fuel.png"

gsap.registerPlugin(ScrollTrigger, useGSAP)

/* Text-safe hero accents: the volt fill (#d9fa36) is too light to read as
   display text on the paper background, so the rotating word uses a darker
   ink of the same hue instead. */
const heroTextAccent: Record<Mode, string> = {
  nutrition: "#5c6d0a",
  workouts: "#ff6b35",
}

/* ------------------------------------------------------------------ */
/*  Inline icon primitives (consistent 1.6 stroke — no icon library)  */
/* ------------------------------------------------------------------ */

type IconProps = { className?: string }
const stroke = {
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.6,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
}

function BoltIcon({ className }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden {...stroke}>
      <path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z" />
    </svg>
  )
}
function BarbellIcon({ className }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden {...stroke}>
      <path d="M4 8v8M7 6v12M17 6v12M20 8v8M7 12h10" />
    </svg>
  )
}
function PulseIcon({ className }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden {...stroke}>
      <path d="M3 12h4l2 6 4-14 2 8h6" />
    </svg>
  )
}
function ClockIcon({ className }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden {...stroke}>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" />
    </svg>
  )
}
function LayersIcon({ className }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden {...stroke}>
      <path d="m12 3 9 5-9 5-9-5 9-5Z" />
      <path d="m3 13 9 5 9-5" />
    </svg>
  )
}
function ArrowIcon({ className }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden {...stroke}>
      <path d="M5 12h14M13 6l6 6-6 6" />
    </svg>
  )
}
function CheckIcon({ className }: IconProps) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden {...stroke}>
      <path d="m4 12 5 5L20 6" />
    </svg>
  )
}

/* ------------------------------------------------------------------ */
/*  Product window mock (faux-OS chrome)                              */
/* ------------------------------------------------------------------ */

const meals = [
  { name: "Breakfast", detail: "Oats, eggs, banana", kcal: 480 },
  { name: "Lunch", detail: "Chicken, rice, greens", kcal: 620 },
  { name: "Snack", detail: "Greek yogurt, almonds", kcal: 260 },
]

const lifts = [
  { name: "Bench press", detail: "4 × 6 @ 82.5 kg", pr: true },
  { name: "Incline DB press", detail: "3 × 10 @ 28 kg", pr: false },
  { name: "Cable fly", detail: "3 × 15 @ 18 kg", pr: false },
]

function WindowChrome({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="overflow-hidden rounded-xl border border-[var(--line)] bg-[var(--surface)]">
      <div className="flex items-center gap-2 border-b border-[var(--line)] px-4 py-2.5">
        <span className="size-2.5 rounded-full bg-[color:rgba(20,18,15,0.14)]" />
        <span className="size-2.5 rounded-full bg-[color:rgba(20,18,15,0.14)]" />
        <span className="size-2.5 rounded-full bg-[color:rgba(20,18,15,0.14)]" />
        <span className="ml-2 font-mono text-[0.7rem] tracking-wide text-[var(--muted)]">
          {label}
        </span>
      </div>
      <div className="p-5">{children}</div>
    </div>
  )
}

function NutritionPanel({ showHeader = true }: { showHeader?: boolean }) {
  return (
    <>
      {showHeader && (
        <div className="flex items-center justify-between">
          <span className="font-mono text-xs text-[var(--muted)]">Monday · Today</span>
          <Badge className="gap-1 border-0 bg-[color:rgba(217,250,54,0.16)] text-[#5c6d0a]">
            <BoltIcon className="size-3" /> 6-day streak
          </Badge>
        </div>
      )}
      <div className={showHeader ? "mt-5 flex items-center gap-5" : "flex items-center gap-5"}>
        <div
          className="relative flex size-24 shrink-0 items-center justify-center rounded-full"
          style={{
            background:
              "conic-gradient(#d9fa36 72%, rgba(20,18,15,0.06) 0)",
          }}
        >
          <div className="absolute inset-[6px] rounded-full bg-[var(--surface)]" />
          <div className="relative text-center">
            <div className="font-mono text-base font-semibold text-[var(--ink)]">
              1,840
            </div>
            <div className="font-mono text-[0.6rem] text-[var(--muted)]">kcal</div>
          </div>
        </div>
        <div className="flex-1 space-y-2">
          {[
            ["Protein", "132g", 82],
            ["Carbs", "190g", 64],
            ["Fat", "58g", 48],
          ].map(([label, val, pct]) => (
            <div key={label as string}>
              <div className="flex justify-between font-mono text-[0.7rem] text-[var(--muted)]">
                <span>{label}</span>
                <span className="text-[var(--ink)]">{val}</span>
              </div>
              <div className="mt-1 h-1.5 rounded-full bg-[color:rgba(20,18,15,0.07)]">
                <div
                  className="h-full rounded-full bg-[var(--ink)]"
                  style={{ width: `${pct}%` }}
                />
              </div>
            </div>
          ))}
        </div>
      </div>
      <div className="mt-5 space-y-2">
        {meals.map((m) => (
          <div
            key={m.name}
            className="flex items-center justify-between rounded-lg border border-[var(--line)] px-3 py-2.5"
          >
            <div>
              <div className="text-sm text-[var(--ink)]">{m.name}</div>
              <div className="text-xs text-[var(--muted)]">{m.detail}</div>
            </div>
            <div className="font-mono text-xs text-[var(--muted)]">{m.kcal} kcal</div>
          </div>
        ))}
      </div>
    </>
  )
}

function TrainingPanel({
  accent = "#ff6b35",
  accentInk = "#b5431c",
}: {
  /** Solid accent (progress bar highlight). */
  accent?: string
  /** Readable ink tone for text/badges on the pale tint. */
  accentInk?: string
}) {
  const bars = [40, 55, 48, 70, 62, 85, 78]
  return (
    <>
      <div className="flex items-center justify-between rounded-lg border border-[var(--line)] px-3 py-2.5">
        <span className="text-sm font-medium text-[var(--ink)]">Push day</span>
        <span className="flex items-center gap-1 font-mono text-xs" style={{ color: accentInk }}>
          <PulseIcon className="size-3.5" /> +2.5 kg PR
        </span>
      </div>
      <div className="mt-2 space-y-2">
        {lifts.map((l) => (
          <div
            key={l.name}
            className="flex items-center justify-between rounded-lg border border-[var(--line)] px-3 py-2.5"
          >
            <div>
              <div className="text-sm text-[var(--ink)]">{l.name}</div>
              <div className="font-mono text-xs text-[var(--muted)]">{l.detail}</div>
            </div>
            {l.pr && (
              <Badge
                className="border-0 text-[0.65rem]"
                style={{ backgroundColor: `${accent}1f`, color: accentInk }}
              >
                PR
              </Badge>
            )}
          </div>
        ))}
      </div>
      <div className="mt-5 flex h-16 items-end gap-1.5">
        {bars.map((h, i) => (
          <div
            key={i}
            className="flex-1 rounded-sm"
            style={{
              height: `${h}%`,
              backgroundColor: i === bars.length - 1 ? accent : "rgba(20,18,15,0.10)",
            }}
          />
        ))}
      </div>
    </>
  )
}

/* ------------------------------------------------------------------ */
/*  Content data                                                      */
/* ------------------------------------------------------------------ */

const features = [
  {
    icon: LayersIcon,
    title: "One log, both halves",
    body: "Food and training share a single day. No context-switching between four different apps to see how your week actually went.",
    span: "md:col-span-3",
  },
  {
    icon: BoltIcon,
    title: "Logged in seconds",
    body: "Recent meals and lifts sit one tap away. A full breakfast entry takes about as long as reading this sentence.",
    span: "md:col-span-3",
  },
  {
    icon: PulseIcon,
    title: "Macros that add up",
    body: "Protein, carbs and fat roll into a live daily total against your target — no spreadsheet, no mental math.",
    span: "md:col-span-2",
  },
  {
    icon: BarbellIcon,
    title: "PRs, tracked quietly",
    body: "Beat a weight or a rep and Fuel marks it. Your progression stays visible set after set.",
    span: "md:col-span-2",
  },
  {
    icon: ClockIcon,
    title: "The streak keeps score",
    body: "One honest entry a day keeps the streak alive. The number does the nagging so you don't have to.",
    span: "md:col-span-2",
  },
]

const steps = [
  {
    n: "01",
    title: "Open to today",
    body: "Fuel starts on the current day — food up top, training below. Nothing to configure before you log.",
  },
  {
    n: "02",
    title: "Log the thing",
    body: "Pick a recent meal or lift, adjust the amount, done. Every entry lands on the same timeline.",
  },
  {
    n: "03",
    title: "Watch it compound",
    body: "Totals settle, PRs get flagged, the streak ticks up. Weeks of small entries become a clear trend.",
  },
]

const stats = [
  { value: 12, suffix: "s", label: "Median time to log a full meal" },
  { value: 2, suffix: "", label: "Halves of your day, one logbook" },
  { value: 100, suffix: "%", label: "Of your history, on one timeline" },
]

/* Scroll-driven showcase — the real app screens, swapped as you scroll. */
const showcase: {
  n: string
  mode: Mode
  url: string
  kicker: string
  title: string
  blurb: string
  Preview: () => ReactElement
}[] = [
  {
    n: "01",
    mode: "nutrition",
    url: "fuel.app / today",
    kicker: "Nutrition",
    title: "Every meal, one honest total.",
    blurb:
      "Log food in seconds and watch calories and macros roll into a single live daily total — with the week behind it for context.",
    Preview: NutritionPreview,
  },
  {
    n: "02",
    mode: "workouts",
    url: "fuel.app / bench press",
    kicker: "Training",
    title: "Beat a number, it's a PR.",
    blurb:
      "One-tap set logging, prefilled from last time. The moment you top a previous weight or rep, Fuel flags the PR and keeps it in your history.",
    Preview: WorkoutPreview,
  },
  {
    n: "03",
    mode: "nutrition",
    url: "fuel.app / coach",
    kicker: "AI Coach",
    title: "A coach that reads your logs.",
    blurb:
      "Fuel reads your real data and hands back a short, specific read on the week — what's working, what's drifting, and one thing to try next.",
    Preview: CoachPreview,
  },
]

const faqs = [
  {
    q: "Is Fuel a food tracker or a workout tracker?",
    a: "Both, on purpose. Most people juggle one app for macros and another for lifts. Fuel keeps them on a single day so you can see how eating and training line up.",
  },
  {
    q: "How long does logging actually take?",
    a: "Recent meals and lifts are one tap from the home screen. A typical entry is a few seconds — the whole idea is that it stays out of your way.",
  },
  {
    q: "Do I need to weigh and measure everything?",
    a: "No. You can log quick portions and dial in accuracy only where it matters. Consistency beats precision, and the streak rewards showing up.",
  },
  {
    q: "What counts as a personal record?",
    a: "Any time you beat a previous weight or rep count on a lift, Fuel flags it as a PR and keeps it in your progression history.",
  },
]

/* ------------------------------------------------------------------ */
/*  Page                                                              */
/* ------------------------------------------------------------------ */

export function LandingEditorial() {
  const root = useRef<HTMLDivElement>(null)
  const insideRef = useRef<HTMLElement>(null)
  /* heroMode only tracks which word is showing, to drive the accent color —
     RotatingText below owns the actual rotation timing/animation. */
  const [heroMode, setHeroMode] = useState<Mode>("nutrition")
  /* Which showcase screen is on stage; driven by scroll on desktop, click-to-jump. */
  const [activeFeature, setActiveFeature] = useState(0)

  const scrollToFeature = (i: number) => {
    const el = insideRef.current
    if (!el) return
    const travel = el.offsetHeight - window.innerHeight
    const top = el.offsetTop + (travel * (i + 0.5)) / showcase.length
    window.scrollTo({ top, behavior: "smooth" })
  }

  useGSAP(
    () => {
      const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches

      /* --- Hero entrance --- */
      if (!reduce) {
        const tl = gsap.timeline({ defaults: { ease: "power3.out" } })
        tl.from(".hero-eyebrow", { autoAlpha: 0, y: 12, duration: 0.6 })
          .from(
            ".hero-line > span",
            { yPercent: 115, duration: 0.9, ease: "expo.out", stagger: 0.1 },
            "-=0.3"
          )
          .from(
            ".hero-headline",
            { filter: "blur(16px)", duration: 1, ease: "power2.out" },
            "<"
          )
          .fromTo(
            ".hero-frame",
            { autoAlpha: 0, scale: 0.95 },
            {
              autoAlpha: 1,
              scale: 1,
              duration: 0.6,
              ease: "power2.out",
              transformOrigin: "50% 50%",
              clearProps: "transform",
            },
            "-=0.45"
          )
          .from(".hero-prop", { autoAlpha: 0, duration: 0.6, stagger: 0.12 }, "-=0.4")
          .from(".hero-sub", { autoAlpha: 0, y: 16, duration: 0.7 }, "-=0.5")
          .fromTo(
            ".hero-cta",
            { autoAlpha: 0, y: 16 },
            {
              autoAlpha: 1,
              y: 0,
              duration: 0.6,
              stagger: 0.08,
              clearProps: "visibility,opacity,transform",
            },
            "-=0.4"
          )
      } else {
        gsap.set(".hero-line > span", { yPercent: 0 })
      }

      /* --- Seamless marquee --- */
      if (!reduce) {
        gsap.to(".marquee-track", {
          xPercent: -50,
          duration: 26,
          ease: "none",
          repeat: -1,
        })
      }

      /* --- Scroll reveals (batched) --- */
      const revealEls = gsap.utils.toArray<HTMLElement>(".reveal")
      if (reduce) {
        gsap.set(revealEls, { autoAlpha: 1, y: 0 })
      } else {
        gsap.set(revealEls, { autoAlpha: 0, y: 26 })
        ScrollTrigger.batch(revealEls, {
          start: "top 88%",
          onEnter: (batch) =>
            gsap.to(batch, {
              autoAlpha: 1,
              y: 0,
              duration: 0.8,
              ease: "power3.out",
              stagger: 0.1,
              overwrite: true,
            }),
        })
      }

      /* --- Process connector line draws on scroll --- */
      if (!reduce) {
        gsap.fromTo(
          ".process-line-fill",
          { scaleY: 0 },
          {
            scaleY: 1,
            ease: "none",
            transformOrigin: "top",
            scrollTrigger: {
              trigger: ".process-list",
              start: "top 70%",
              end: "bottom 70%",
              scrub: true,
            },
          }
        )
      }

      /* --- Count-up stats --- */
      gsap.utils.toArray<HTMLElement>(".stat-num").forEach((el) => {
        const target = Number(el.dataset.count || "0")
        if (reduce) {
          el.textContent = String(target)
          return
        }
        const obj = { val: 0 }
        gsap.to(obj, {
          val: target,
          duration: 1.6,
          ease: "power2.out",
          scrollTrigger: { trigger: el, start: "top 85%", once: true },
          onUpdate: () => {
            el.textContent = String(Math.round(obj.val))
          },
        })
      })

      /* --- Nav gains a glass backing as soon as the page scrolls --- */
      ScrollTrigger.create({
        start: 24,
        end: "max",
        onToggle: (self) =>
          document.querySelector(".site-nav")?.classList.toggle("is-scrolled", self.isActive),
      })

      /* --- Inside Fuel: pin the stage, swap the on-screen app as you scroll.
         Desktop only — mobile renders the three screens stacked. --- */
      const inside = insideRef.current
      if (inside && window.matchMedia("(min-width: 768px)").matches) {
        ScrollTrigger.create({
          trigger: inside,
          start: "top top",
          end: "bottom bottom",
          onUpdate: (self) => {
            const idx = Math.min(
              showcase.length - 1,
              Math.floor(self.progress * showcase.length)
            )
            setActiveFeature(idx)
          },
        })
      }
    },
    { scope: root }
  )

  return (
    <div
      ref={root}
      className="min-h-screen font-sans antialiased [--citrus-ink:#b5431c] [--citrus-tint:rgba(255,107,53,0.12)] [--citrus:#ff6b35] [--ink-2:#1c1914] [--ink:#14120f] [--line:rgba(20,18,15,0.10)] [--muted:#6f6a5c] [--paper-2:#efe8d7] [--paper:#f7f3ea] [--surface:#fffdf7] [--volt:#d9fa36]"
      style={{ backgroundColor: "var(--paper)", color: "var(--ink)" }}
    >
      {/* ---------------- Nav ---------------- */}
      <header className="site-nav sticky top-0 z-50">
        <div className="mx-auto max-w-6xl px-4 pt-4 sm:px-6">
          <div className="nav-pill flex items-center justify-between gap-6 rounded-full py-2.5 pl-3 pr-3">
            <div className="flex items-center gap-2.5 pl-1">
              <img src={fuelLogo} alt="" className="size-9 rounded-xl" aria-hidden="true" />
              <span className="font-heading font-semibold text-xl leading-none tracking-tight text-[var(--ink)]">
                Fuel
              </span>
            </div>
            <nav className="hidden items-center gap-7 md:flex">
              {["Features", "Two sides", "Process", "FAQ"].map((l) => (
                <a
                  key={l}
                  href={`#${l.toLowerCase().replace(" ", "-")}`}
                  className="nav-link text-sm font-medium text-[var(--muted)] transition-colors hover:text-[var(--ink)]"
                >
                  {l}
                </a>
              ))}
            </nav>
            <Button
              asChild
              size="lg"
              className="h-10 rounded-full bg-[var(--ink)] px-5 text-sm font-medium text-[var(--paper)] shadow-sm hover:bg-[var(--ink-2)]"
            >
              <Link to="/dashboard">Open the app</Link>
            </Button>
          </div>
        </div>
      </header>

      {/* ---------------- Hero ---------------- */}
      <section className="hero-section relative overflow-hidden">
        {/* design canvas: a faint measured grid, dashed guides, and floating
            tool chips — the workspace behind the "selected" headline. */}
        <div className="pointer-events-none absolute inset-0" aria-hidden>
          <div className="hero-grid absolute inset-0" />
          {/* dashed guides crossing near the headline */}
          <div
            className="absolute inset-y-0 left-[38%] w-px"
            style={{
              backgroundImage:
                "repeating-linear-gradient(to bottom, rgba(255,107,53,0.26) 0 6px, transparent 6px 13px)",
            }}
          />
          <div
            className="absolute inset-x-0 top-[45%] h-px"
            style={{
              backgroundImage:
                "repeating-linear-gradient(to right, rgba(255,107,53,0.2) 0 6px, transparent 6px 13px)",
            }}
          />
          {/* floating tool chips — hidden on small screens so they never crowd
              the copy */}
          <div className="absolute inset-0 hidden md:block">
            <div className="hero-prop absolute right-[15%] top-[22%] [--rot:-8deg]">
              <span className="grid size-12 place-items-center rounded-2xl border border-[var(--line)] bg-[var(--surface)] text-[var(--citrus-ink)] shadow-[0_12px_34px_-14px_rgba(20,18,15,0.32)]">
                <BarbellIcon className="size-6" />
              </span>
            </div>
            <div className="hero-prop absolute right-[29%] top-[57%] [--rot:6deg]">
              <span className="grid size-10 place-items-center rounded-xl border border-[var(--line)] bg-[var(--surface)] text-[var(--citrus)] shadow-[0_12px_34px_-14px_rgba(20,18,15,0.32)]">
                <BoltIcon className="size-5" />
              </span>
            </div>
            <div className="hero-prop absolute right-[8%] top-[63%] [--rot:12deg]">
              <span className="grid size-9 place-items-center rounded-xl border border-[var(--line)] bg-[var(--surface)] text-[var(--muted)] shadow-[0_12px_34px_-14px_rgba(20,18,15,0.32)]">
                <PulseIcon className="size-4" />
              </span>
            </div>
          </div>
        </div>
        {/* ambient warm light */}
        <div
          className="pointer-events-none absolute -top-40 left-1/2 h-[520px] w-[820px] -translate-x-1/2 rounded-full"
          style={{
            background:
              "radial-gradient(closest-side, rgba(255,107,53,0.12), transparent 70%)",
          }}
        />
        <div className="relative mx-auto max-w-6xl px-6 py-20 md:py-28">
          <div className="relative z-20 max-w-2xl">
            <div className="hero-eyebrow mb-6 inline-flex items-center gap-2 rounded-full border border-[var(--line)] bg-[var(--surface)] px-3 py-1">
              <span className="size-1.5 rounded-full bg-[var(--citrus)]" />
              <span className="font-mono text-[0.7rem] uppercase tracking-[0.14em] text-[var(--muted)]">
                One log for food and training
              </span>
            </div>

            <div className="hero-select relative inline-block">
            <h1 className="hero-headline font-heading text-[clamp(2.9rem,7vw,5.2rem)] font-semibold leading-[0.98] tracking-[-0.035em]">
              <span className="hero-line -my-[0.12em] block overflow-hidden py-[0.12em]">
                <span className="block">Log every</span>
              </span>
              <span className="hero-line -my-[0.12em] block overflow-hidden py-[0.12em]">
                <span className="relative block">
                  <motion.span
                    animate={{ color: heroTextAccent[heroMode] }}
                    transition={{ duration: 0.4, ease: "easeOut" }}
                    className="inline-block"
                  >
                    <RotatingText
                      texts={["meal", "set"]}
                      rotationInterval={2600}
                      // popLayout lets the exiting word animate out while the
                      // next one animates in at the same time — "wait" (the
                      // component default) fully finishes the exit before the
                      // enter even starts, which reads as a hard cut.
                      animatePresenceMode="popLayout"
                      staggerFrom="first"
                      staggerDuration={0.03}
                      transition={{ type: "spring", damping: 22, stiffness: 260 }}
                      onNext={(index) => setHeroMode(index === 0 ? "nutrition" : "workouts")}
                    />
                  </motion.span>
                  .
                </span>
              </span>
              <span className="hero-line -my-[0.12em] block overflow-hidden py-[0.12em]">
                <span className="block text-[color:rgba(20,18,15,0.6)]">Build the streak.</span>
              </span>
            </h1>
              {/* selection frame — the headline shown "selected", design-tool style */}
              <span className="hero-frame pointer-events-none absolute -inset-x-4 -inset-y-3" aria-hidden>
                <span className="absolute inset-0 rounded-[2px] border border-[var(--citrus)] opacity-80" />
                <span className="absolute -top-[1.4rem] left-0 rounded-[3px] bg-[var(--citrus)] px-1.5 py-0.5 font-mono text-[0.6rem] font-medium leading-none text-white">
                  headline
                </span>
                {[
                  "-top-1 -left-1",
                  "-top-1 -right-1",
                  "-bottom-1 -left-1",
                  "-bottom-1 -right-1",
                  "top-1/2 -left-1 -translate-y-1/2",
                  "top-1/2 -right-1 -translate-y-1/2",
                  "-top-1 left-1/2 -translate-x-1/2",
                  "-bottom-1 left-1/2 -translate-x-1/2",
                ].map((pos) => (
                  <span
                    key={pos}
                    className={`absolute size-2 rounded-[1px] border border-white bg-[var(--citrus)] shadow-sm ${pos}`}
                  />
                ))}
              </span>
            </div>

            <p className="hero-sub mt-7 max-w-md text-lg leading-relaxed text-[color:#57534a]">
              Fuel is the logbook for your body — macros and meals on one side,
              sets and PRs on the other. Logged in seconds, kept on a single
              timeline.
            </p>

            <div className="mt-8 flex flex-wrap items-center gap-3">
              <Button
                asChild
                size="lg"
                className="hero-cta h-11 gap-2 rounded-md bg-[var(--ink)] px-5 text-[15px] text-[var(--paper)] hover:bg-[var(--ink-2)]"
              >
                <Link to="/dashboard">
                  Start your logbook <ArrowIcon className="size-4" />
                </Link>
              </Button>
              <a
                href="#two-sides"
                className="hero-cta inline-flex h-11 items-center rounded-md border border-[var(--line)] bg-[var(--surface)] px-5 text-[15px] font-medium text-[var(--ink)] transition-colors hover:bg-[var(--paper-2)]"
              >
                See how it works
              </a>
            </div>

            <div className="hero-cta mt-8 flex items-center gap-6 font-mono text-[0.72rem] text-[color:#57534a]">
              <span className="flex items-center gap-1.5">
                <CheckIcon className="size-3.5 text-[var(--citrus)]" /> No setup
              </span>
              <span className="flex items-center gap-1.5">
                <CheckIcon className="size-3.5 text-[var(--citrus)]" /> Free to start
              </span>
              <span className="flex items-center gap-1.5">
                <CheckIcon className="size-3.5 text-[var(--citrus)]" /> Your data stays yours
              </span>
            </div>
          </div>
        </div>
      </section>

      {/* ---------------- Marquee ---------------- */}
      <div className="overflow-hidden border-y border-[var(--line)] bg-[var(--paper-2)] py-4">
        <div className="marquee-track flex w-max whitespace-nowrap font-heading font-medium text-2xl text-[var(--muted)]">
          {[0, 1].map((dup) => (
            <div key={dup} className="flex shrink-0 items-center">
              {["Meals", "Macros", "Sets", "Reps", "PRs", "Streaks", "Protein", "Progress"].map(
                (w) => (
                  <span key={w} className="flex items-center">
                    <span className="px-8">{w}</span>
                    <span className="text-[var(--citrus)]">/</span>
                  </span>
                )
              )}
            </div>
          ))}
        </div>
      </div>

      {/* ---------------- Features (bento) ---------------- */}
      <section id="features" className="mx-auto max-w-6xl px-6 py-24 md:py-32">
        <div className="reveal max-w-2xl">
          <span className="font-mono text-xs uppercase tracking-[0.16em] text-[var(--citrus-ink)]">
            Why Fuel
          </span>
          <h2 className="mt-4 font-heading font-medium text-[clamp(2rem,4vw,3rem)] leading-[1.05] tracking-[-0.02em]">
            Two habits, one honest record.
          </h2>
          <p className="mt-4 text-[var(--muted)]">
            Everything here exists to make logging so fast you keep doing it —
            and to put food and training back on the same page.
          </p>
        </div>

        <div className="mt-14 grid gap-4 md:grid-cols-6">
          {features.map((f) => (
            <article
              key={f.title}
              className={`reveal group flex flex-col rounded-xl border border-[var(--line)] bg-[var(--surface)] p-7 transition-shadow duration-200 hover:shadow-[0_2px_14px_rgba(20,18,15,0.05)] ${f.span}`}
            >
              <span className="grid size-10 place-items-center rounded-lg bg-[var(--citrus-tint)] text-[var(--citrus-ink)]">
                <f.icon className="size-5" />
              </span>
              <h3 className="mt-5 text-lg font-medium tracking-tight text-[var(--ink)]">
                {f.title}
              </h3>
              <p className="mt-2 text-[15px] leading-relaxed text-[var(--muted)]">
                {f.body}
              </p>
            </article>
          ))}
        </div>
      </section>

      {/* ---------------- Inside Fuel (scroll showcase) ---------------- */}
      <section
        ref={insideRef}
        id="inside"
        className="relative border-t border-[var(--line)] bg-[var(--paper-2)] md:h-[320vh]"
      >
        <div className="md:sticky md:top-0 md:flex md:h-screen md:items-center">
          <div className="mx-auto w-full max-w-6xl px-6 py-16 md:py-0">
            {/* heading */}
            <div className="reveal max-w-2xl">
              <span className="font-mono text-xs uppercase tracking-[0.16em] text-[var(--citrus-ink)]">
                Inside Fuel
              </span>
              <h2 className="mt-4 font-heading font-medium text-[clamp(2rem,4vw,3rem)] leading-[1.05] tracking-[-0.02em]">
                The real app,{" "}
                <span className="relative whitespace-nowrap">
                  not a mockup.
                  <svg
                    className="absolute -bottom-1.5 left-0 h-2.5 w-full text-[var(--citrus)]"
                    viewBox="0 0 200 10"
                    fill="none"
                    preserveAspectRatio="none"
                    aria-hidden
                  >
                    <path
                      d="M2 7C40 2 70 9 108 5s72-4 90 1"
                      stroke="currentColor"
                      strokeWidth="3"
                      strokeLinecap="round"
                    />
                  </svg>
                </span>
              </h2>
              <p className="mt-4 text-[var(--muted)]">
                Everything below is Fuel's actual interface, wired to live example
                data. Scroll to move through it.
              </p>
            </div>

            {/* desktop: pinned stage that swaps on scroll */}
            <div className="mt-12 hidden gap-12 md:grid md:grid-cols-[minmax(0,0.82fr)_minmax(0,1.18fr)]">
              {/* feature list */}
              <div className="self-center">
                <div className="flex flex-col gap-2">
                  {showcase.map((f, i) => {
                    const active = i === activeFeature
                    return (
                      <button
                        key={f.n}
                        type="button"
                        onClick={() => scrollToFeature(i)}
                        className={`group relative overflow-hidden rounded-xl border px-5 py-4 text-left transition-all duration-300 ${
                          active
                            ? "border-[var(--line)] bg-[var(--surface)] shadow-[0_2px_18px_rgba(20,18,15,0.06)]"
                            : "border-transparent opacity-55 hover:opacity-90"
                        }`}
                      >
                        <span
                          className={`absolute inset-y-3 left-0 w-0.5 rounded-full bg-[var(--citrus)] transition-opacity duration-300 ${
                            active ? "opacity-100" : "opacity-0"
                          }`}
                        />
                        <div className="flex items-center gap-3">
                          <span
                            className={`font-mono text-xs ${
                              active ? "text-[var(--citrus-ink)]" : "text-[var(--muted)]"
                            }`}
                          >
                            {f.n}
                          </span>
                          <span className="font-mono text-[0.7rem] uppercase tracking-[0.16em] text-[var(--muted)]">
                            {f.kicker}
                          </span>
                        </div>
                        <h3 className="mt-2 font-heading text-xl font-medium tracking-tight text-[var(--ink)]">
                          {f.title}
                        </h3>
                        <div
                          className="grid transition-[grid-template-rows] duration-300 ease-out"
                          style={{ gridTemplateRows: active ? "1fr" : "0fr" }}
                        >
                          <p className="overflow-hidden text-[15px] leading-relaxed text-[var(--muted)]">
                            <span className="block pt-2">{f.blurb}</span>
                          </p>
                        </div>
                      </button>
                    )
                  })}
                </div>
              </div>

              {/* framed screen — crossfades between the app screens */}
              <div className="self-center">
                <div className="relative h-[620px]">
                  {showcase.map((f, i) => {
                    const Preview = f.Preview
                    return (
                      <div
                        key={f.n}
                        className={`absolute inset-0 transition-all duration-500 ease-out ${
                          i === activeFeature
                            ? "opacity-100 translate-y-0"
                            : "pointer-events-none translate-y-3 opacity-0"
                        }`}
                        aria-hidden={i !== activeFeature}
                      >
                        <ScreenFrame url={f.url} mode={f.mode} className="h-full">
                          <Preview />
                        </ScreenFrame>
                      </div>
                    )
                  })}
                </div>
              </div>
            </div>

            {/* mobile: the same screens, stacked */}
            <div className="mt-10 flex flex-col gap-12 md:hidden">
              {showcase.map((f) => {
                const Preview = f.Preview
                return (
                  <div key={f.n} className="reveal">
                    <div className="flex items-center gap-3">
                      <span className="font-mono text-xs text-[var(--citrus-ink)]">{f.n}</span>
                      <span className="font-mono text-[0.7rem] uppercase tracking-[0.16em] text-[var(--muted)]">
                        {f.kicker}
                      </span>
                    </div>
                    <h3 className="mt-2 font-heading text-xl font-medium tracking-tight text-[var(--ink)]">
                      {f.title}
                    </h3>
                    <p className="mt-2 text-[15px] leading-relaxed text-[var(--muted)]">
                      {f.blurb}
                    </p>
                    <div className="mt-5">
                      <ScreenFrame url={f.url} mode={f.mode}>
                        <Preview />
                      </ScreenFrame>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        </div>
      </section>

      {/* ---------------- Two sides (Tabs) ---------------- */}
      <section id="two-sides" className="border-y border-[var(--line)] bg-[var(--paper-2)]">
        <div className="mx-auto grid max-w-6xl gap-14 px-6 py-24 md:grid-cols-2 md:items-center md:py-32">
          <div className="reveal">
            <span className="font-mono text-xs uppercase tracking-[0.16em] text-[var(--citrus-ink)]">
              One app, two sides
            </span>
            <h2 className="mt-4 font-heading font-medium text-[clamp(2rem,4vw,3rem)] leading-[1.05] tracking-[-0.02em]">
              The same day, seen from both directions.
            </h2>
            <p className="mt-4 max-w-md text-[var(--muted)]">
              Flip between what you ate and what you lifted without leaving the
              day you're on. The numbers live next to each other, the way your
              body actually experiences them.
            </p>
            <Separator className="my-8 bg-[var(--line)]" />
            <ul className="space-y-3">
              {[
                "Macros roll up to a live daily total",
                "Lifts track weight, reps and PRs",
                "Streak spans both — miss neither",
              ].map((t) => (
                <li key={t} className="flex items-center gap-3 text-[15px] text-[var(--ink)]">
                  <span className="grid size-5 shrink-0 place-items-center rounded-full bg-[var(--citrus)] text-[var(--paper)]">
                    <CheckIcon className="size-3" />
                  </span>
                  {t}
                </li>
              ))}
            </ul>
          </div>

          <div className="reveal">
            <Tabs defaultValue="nutrition" className="gap-5">
              <TabsList className="w-full bg-[var(--surface)]">
                <TabsTrigger value="nutrition" className="flex-1 gap-1.5">
                  <BoltIcon className="size-3.5" /> Nutrition
                </TabsTrigger>
                <TabsTrigger value="training" className="flex-1 gap-1.5">
                  <BarbellIcon className="size-3.5" /> Training
                </TabsTrigger>
              </TabsList>
              <TabsContent value="nutrition">
                <WindowChrome label="fuel · nutrition">
                  <NutritionPanel />
                </WindowChrome>
              </TabsContent>
              <TabsContent value="training">
                <WindowChrome label="fuel · training">
                  <TrainingPanel />
                </WindowChrome>
              </TabsContent>
            </Tabs>
          </div>
        </div>
      </section>

      {/* ---------------- Process ---------------- */}
      <section id="process" className="mx-auto max-w-6xl px-6 py-24 md:py-32">
        <div className="reveal max-w-2xl">
          <span className="font-mono text-xs uppercase tracking-[0.16em] text-[var(--citrus-ink)]">
            The loop
          </span>
          <h2 className="mt-4 font-heading font-medium text-[clamp(2rem,4vw,3rem)] leading-[1.05] tracking-[-0.02em]">
            Three steps. Every single day.
          </h2>
        </div>

        <div className="process-list relative mt-14 pl-10">
          {/* connector line */}
          <div className="absolute left-[15px] top-2 bottom-2 w-px bg-[var(--line)]">
            <div className="process-line-fill h-full w-px origin-top bg-[var(--citrus)]" />
          </div>
          <div className="space-y-10">
            {steps.map((s) => (
              <div key={s.n} className="reveal relative">
                <span className="absolute -left-10 grid size-8 place-items-center rounded-full border border-[var(--line)] bg-[var(--surface)] font-mono text-xs text-[var(--ink)]">
                  {s.n}
                </span>
                <h3 className="font-heading font-medium text-2xl tracking-tight text-[var(--ink)]">
                  {s.title}
                </h3>
                <p className="mt-2 max-w-xl text-[15px] leading-relaxed text-[var(--muted)]">
                  {s.body}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ---------------- Stats ---------------- */}
      <section className="border-y border-[var(--line)] bg-[var(--paper-2)]">
        <div className="mx-auto grid max-w-6xl gap-10 px-6 py-20 sm:grid-cols-3">
          {stats.map((s) => (
            <div key={s.label} className="reveal text-center sm:text-left">
              <div className="font-heading font-medium text-6xl tracking-tight text-[var(--ink)]">
                <span className="stat-num" data-count={s.value}>
                  0
                </span>
                <span className="text-[var(--citrus)]">{s.suffix}</span>
              </div>
              <p className="mt-3 text-sm text-[var(--muted)]">{s.label}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ---------------- Pull quote ---------------- */}
      <section className="mx-auto max-w-4xl px-6 py-24 text-center md:py-32">
        <blockquote className="reveal font-heading text-[clamp(1.8rem,3.6vw,2.8rem)] font-medium leading-[1.3] tracking-[-0.025em] text-[var(--ink)]">
          “I stopped juggling a food app and a lifting app.{" "}
          <span className="font-normal text-[var(--muted)]">
            Now it's one screen, one streak, and I actually keep it going.
          </span>
          ”
        </blockquote>
        <div className="reveal mt-8 flex items-center justify-center gap-3">
          <span className="grid size-9 place-items-center rounded-full bg-[var(--ink)] font-mono text-xs text-[var(--paper)]">
            RM
          </span>
          <div className="text-left">
            <div className="text-sm font-medium text-[var(--ink)]">Rana Malik</div>
            <div className="font-mono text-xs text-[var(--muted)]">
              Logged 214 days straight
            </div>
          </div>
        </div>
      </section>

      {/* ---------------- FAQ ---------------- */}
      <section id="faq" className="border-t border-[var(--line)] bg-[var(--paper-2)]">
        <div className="mx-auto grid max-w-6xl gap-14 px-6 py-24 md:grid-cols-[0.8fr_1.2fr] md:py-32">
          <div className="reveal">
            <span className="font-mono text-xs uppercase tracking-[0.16em] text-[var(--citrus-ink)]">
              Questions
            </span>
            <h2 className="mt-4 font-heading font-medium text-[clamp(2rem,4vw,3rem)] leading-[1.05] tracking-[-0.02em]">
              Before you start.
            </h2>
          </div>
          <div className="reveal">
            {faqs.map((f) => (
              <details
                key={f.q}
                className="group border-b border-[var(--line)] py-5 [&_summary::-webkit-details-marker]:hidden"
              >
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-[17px] font-medium text-[var(--ink)]">
                  {f.q}
                  <span className="relative grid size-5 shrink-0 place-items-center text-[var(--muted)]">
                    <span className="absolute h-px w-3.5 bg-current" />
                    <span className="absolute h-3.5 w-px bg-current transition-transform duration-200 group-open:scale-y-0" />
                  </span>
                </summary>
                <p className="mt-3 max-w-xl text-[15px] leading-relaxed text-[var(--muted)]">
                  {f.a}
                </p>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* ---------------- CTA ---------------- */}
      <section className="px-6 py-24 md:py-32">
        <div className="reveal relative mx-auto max-w-5xl overflow-hidden rounded-2xl bg-[var(--ink)] px-8 py-16 text-center md:px-16 md:py-20">
          <div
            className="pointer-events-none absolute -top-24 left-1/2 h-80 w-[640px] -translate-x-1/2 rounded-full"
            style={{
              background:
                "radial-gradient(closest-side, rgba(255,107,53,0.22), transparent 70%)",
            }}
          />
          <h2 className="relative font-heading font-medium text-[clamp(2.2rem,5vw,3.6rem)] leading-[1.02] tracking-[-0.02em] text-[var(--paper)]">
            Start the streak today.
          </h2>
          <p className="relative mx-auto mt-5 max-w-md text-[var(--paper)]/70">
            One log for what you eat and what you lift. It takes a few seconds —
            and it compounds.
          </p>
          <div className="relative mt-9 flex flex-wrap justify-center gap-3">
            <Button
              asChild
              size="lg"
              className="h-11 gap-2 rounded-md bg-[var(--citrus)] px-6 text-[15px] text-[var(--ink)] hover:bg-[color:#ff7d4d]"
            >
              <Link to="/dashboard">
                Open Fuel <ArrowIcon className="size-4" />
              </Link>
            </Button>
            <a
              href="#features"
              className="inline-flex h-11 items-center rounded-md border border-[color:rgba(247,243,234,0.2)] px-6 text-[15px] font-medium text-[var(--paper)] transition-colors hover:bg-[color:rgba(247,243,234,0.08)]"
            >
              Explore features
            </a>
          </div>
        </div>
      </section>

      {/* ---------------- Footer ---------------- */}
      <footer className="border-t border-[var(--line)]">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-6 px-6 py-10 sm:flex-row">
          <div className="flex items-center gap-2">
            <img src={fuelLogo} alt="" className="size-9 rounded-lg" aria-hidden="true" />
            <span className="font-heading font-medium text-xl tracking-tight">Fuel</span>
          </div>
          <p className="font-mono text-xs text-[var(--muted)]">
            The logbook for your body — meals and lifts, one timeline.
          </p>
          <div className="flex gap-6 text-sm text-[var(--muted)]">
            <a href="#features" className="transition-colors hover:text-[var(--ink)]">
              Features
            </a>
            <a href="#faq" className="transition-colors hover:text-[var(--ink)]">
              FAQ
            </a>
            <Link to="/dashboard" className="transition-colors hover:text-[var(--ink)]">
              App
            </Link>
          </div>
        </div>
      </footer>
    </div>
  )
}

export default LandingEditorial
