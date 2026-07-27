# Fuel iOS — Design System & Engineering Conventions

Read this fully before writing any code. Every screen must feel like the same app.
The bar is: **a polished, professional iOS 26 app** — Liquid Glass, seamless, fast, obvious.

## Product identity

Fuel is a nutrition tracker (Egypt-first food data, AI assisted). The identity is **dark-only** —
a charcoal canvas with an "activity rings" hero (green calories + blue protein), a direct port of the
web app's dark Today redesign. The app locks to dark via `.preferredColorScheme(.dark)` on `RootView`,
so every color set is scheme-independent (a single universal value renders identically light/dark).

| Token (asset catalog name) | Value | Use |
|---|---|---|
| `FuelBackground` | `#0B0D11` charcoal | screen background |
| `FuelSurface` | `#17191F` | solid grouped list rows (cards use glass, below) |
| `FuelInk` | `#F3F5F7` near-white | primary text |
| `FuelSubtle` | `#9099A3` | secondary text |
| `FuelVolt` | `#4BE08A` green | brand accent FILL — primary buttons, plus disc, selection, calorie ring |
| `FuelVoltInk` | `#5CE39B` green | brand green **text/icons/thin strokes** (date eyebrow, links, active tab, fat readouts) |
| `FuelOlive` | `#4BE08A` green | the LARGE green fill (calorie ring, fat/goal bars, on-target chart bars). Same green as volt |
| `FuelOver` | `#FF7A59` coral | over-target signal (pace line, over pills, over-ring). Warm, never alarm red |
| `FuelCitrus` | `#4BE08A` green | **historical name — now the green brand accent.** Kept so the many accent call-sites (button tints, links, active states) re-point without edits. NOT protein |
| `FuelCitrusInk` | `#5CE39B` green | green brand accent ink (same role as `FuelVoltInk`) |
| `FuelBlue` | `#3F8DFF` blue | **protein** fill — the inner ring + protein macro bar |
| `FuelBlueInk` | `#5C9DFF` blue | **protein** text/icons (protein readouts, protein stat tiles) |
| `FuelGold` / `FuelGoldInk` | `#D9A441` / `#E7C46B` | carbs fill / ink |
| `FuelDestructive` | `#FF6B6B` | delete/danger |

Define all as color sets in `Fuel/Resources/Assets.xcassets` (asset symbol generation is on), expose
via `Color.fuelVolt`-style extensions. Never hardcode hex in views (the only exceptions are the
full-screen camera overlay in `BarcodeScanView`, which is black/white over a live feed).

Macro color convention (matches the web dark identity): **protein = blue** (`FuelBlue` / `FuelBlueInk`),
**carbs = gold** (`FuelGold` / `FuelGoldInk`), **fat = green** (`FuelOlive` / `FuelVoltInk`), and
**calories = green** (`FuelOlive`). Progress bars NEVER turn red when over target — they keep their
macro color and clamp at 100%; "over" is signalled by the pace line / pills in `FuelOver`.
`FuelDestructive` is reserved exclusively for destructive actions.

## Typography — same identity as the web app

The iOS type system is a direct mirror of the web app's design tokens (`frontend/src/index.css`).
**There is NO serif anywhere** — the old `.fontDesign(.serif)` mastheads were off-brand and have
been removed. Three variable fonts are bundled (`Fuel/Resources/Fonts`, registered in
`Config/Info.plist` `UIAppFonts`) and wired up in `DesignSystem/FuelTypography.swift`:

| Family | Web token | Used for |
|---|---|---|
| **Google Sans Flex 18pt** (wght 1–1000) | `--font-heading` + `--font-sans` | ALL headings, the "Fuel" wordmark, section titles, and ALL body text |
| **JetBrains Mono** (wght 100–800) | `--font-mono` | ALL numerals, kcal values, macro P/C/F labels, stat readouts, and the uppercase tracking eyebrows |
| **Cairo** (wght 200–1000) | Arabic `--font-heading`/`--font-sans` | swaps in for Google Sans Flex when the app language is Arabic (mono stays JetBrains Mono, Cairo covers Arabic-Indic digits via the system cascade) |

Use the semantic API — never `Font.custom(...)` or `.system(...)` for content text, and never a serif:

- `Font.fuelHeading(_:weight:)` / `.fuelBody(_:weight:)` → Google Sans Flex (Cairo in Arabic). Both
  take a point size or a `Font.TextStyle` (e.g. `.fuelBody(.subheadline)`), and both scale with
  Dynamic Type. `weight` is a 1–1000 axis value (400 regular, 500 medium, 600 semibold, 700 bold) —
  it drives the variable `wght` axis directly via `UIFontDescriptor` (SwiftUI's `.weight()` does NOT
  reliably move a variable axis, which is why we set the coordinate ourselves).
- Named roles: `.fuelMasthead` (~34 bold), `.fuelTitle` (~27 semibold), `.fuelTitle2` (~22 semibold),
  `.fuelStatNumber` (big mono ring readout), `.fuelMetric` (mono stat-tile number).
- `Font.fuelMono(_:weight:)` → JetBrains Mono for every number and code-like value (default weight 500).
- **Eyebrows:** `.fuelEyebrow()` (the `EyebrowStyle` modifier) — mono, ~11pt, uppercase, `~0.14em`
  tracking, `fuelSubtle`. This is the small "TODAY" / "CALORIES" / "COACH" label above titles and
  the "kcal" caption under numbers. Tracking is applied at the Text/View level (a `Font` can't carry
  it), so always go through the modifier.
- System chrome (nav-bar large + inline titles) is branded to Google Sans Flex globally in
  `FuelApp.configureNavigationBarTypography()`; a root `.font(.fuelBody(.body))` on `RootView` keeps
  any unstyled text (Form labels, list rows) on the brand face too.
- SF Symbols keep `.font(.system(size:))` / `.body.weight(...)` — those size glyphs, not text.

## Shape & surfaces — dark glass

- **Corner radius:** cards/surfaces use **18pt** continuous corners (`FuelRadius.card`, mirrors the
  web `--radius: 1.1rem`); small elements (inputs, chips) use **12pt** (`FuelRadius.small`).
- **Cards are dark Liquid Glass:** use the `.fuelCard()` modifier — a `.regular` `.glassEffect` panel
  with an 18pt continuous shape and a hairline `Color.white.opacity(0.08)` edge, **no drop shadow**.
  Depth comes from the glass material, not shadows. This is the frosted-panel look on the charcoal
  canvas (matching the web's faint `white/3` translucent cards, elevated with the iOS 26 material).
- The Today hero is **bare on the canvas** (no card): the `ActivityRings` component IS the hero —
  two concentric rings (green calories / blue protein), the two headline numbers stacked in Google
  Sans Flex at the center, a legend, and a Carbs/Fat/Remaining stat strip.
- Solid grouped list rows still use `Color.fuelSurface` via `.listRowBackground(...)`.

## Liquid Glass — how we use it

We build with the iOS 26 SDK; Liquid Glass is the point, not an afterthought. Rules:

1. **System-first.** `TabView`, `NavigationStack` toolbars, `.searchable`, sheets, alerts and menus
   get Liquid Glass automatically. Prefer system containers/controls over custom chrome — that is
   80% of the "professional" feel.
2. **Custom glass only on the floating layer** — controls and elements that sit *above* content:
   floating action buttons, the log toolbar, portion chips overlay, scanner overlay controls.
   Use `.glassEffect()` / `.glassEffect(.regular.tint(...).interactive())`, and wrap sibling glass
   elements in a `GlassEffectContainer` so they blend/morph correctly. Use `glassEffectID(_:in:)`
   with `@Namespace` when a control morphs (e.g. toolbar expanding into actions).
3. **Content cards ARE dark glass.** On the charcoal canvas, `.fuelCard()` uses `.glassEffect` so
   cards read as frosted glass panels — the identity leans into the material rather than flat fills.
   Bare text/rows still sit directly on `FuelBackground`/`FuelSurface`.
4. Buttons: primary actions `.buttonStyle(.glassProminent)` tinted `FuelVolt` (green — the default
   `AsyncButton` tint), secondary `.buttonStyle(.glass)`. Never fake glass with `.ultraThinMaterial`.
5. Scroll edges: use `.scrollEdgeEffectStyle(.soft, for: .top)` where content scrolls under bars —
   never paint opaque bars.

## UX principles (senior-level; every screen is judged on these)

- **One primary action per screen**, visually dominant. Everything else is secondary.
- **Never block on the network for local data.** Personal log reads render instantly from the last
  fetch; refreshes reconcile quietly. Writes are optimistic where the web app is (delete rows,
  set edits) with rollback on failure.
- **Every async control shows its state in place** (button → spinner → checkmark, disabled while
  in flight). No dead taps, no double-submits. A tiny `LoadingButton`/`AsyncButton` component is
  shared by everyone.
- **Empty, loading, error are designed states**, not afterthoughts: `ContentUnavailableView` for
  empties (with a next-step action), `.redacted(reason: .placeholder)` skeletons for first loads,
  inline retry banners for failures. Render cold-start (~30–60 s) gets a friendly
  "Waking the server…" state after ~3 s, with retry.
- **Soft-fail AI results are states, not errors** (`ok: false`, `found: false`, `readable: false`)
  — show "couldn't read the label / product not found" with a manual-entry path.
- **Haptics**: `.sensoryFeedback(.success, …)` on meal logged / goal events, `.impact` on
  destructive confirm. Sparingly — meaningful moments only.
- **Motion**: default spring animations; `withAnimation(.snappy)` for list mutations;
  `contentTransition(.numericText())` on changing numbers (calorie ring, totals). No gratuitous
  animation.
- **Keyboards**: numeric fields use `.keyboardType(.decimalPad)` + a Done toolbar
  (`ToolbarItemGroup(placement: .keyboard)`), `@FocusState` moves focus in forms. Parse numbers
  through `NumberFormatter`/`Locale`-aware parsing, never `Double(string)` (Arabic separators).
- **Dynamic Type** must not break layouts; test `.xxxLarge`. All tap targets ≥ 44 pt.
- **Numerals are always JetBrains Mono** (`Font.fuelMono`) — it is inherently monospaced, so it
  replaces the old `.monospacedDigit()` styling. See the Typography section for the full system.
- Currency of information: today's screen answers "how am I doing right now?" in one glance —
  ring, remaining kcal, pace label. Detail lives one tap deeper.

## Architecture conventions

- Swift 5 language mode, iOS 26 deployment target, SwiftUI only, async/await everywhere.
- `@Observable` (Observation framework) for state. One `AppState` in `.environment`; per-screen
  view models owned with `@State`. No singletons except `AppConfig`/`SupabaseService.shared`.
- File layout (filesystem-synchronized — adding a file on disk adds it to the target):
  `Fuel/App`, `Fuel/Core/{Networking,Supabase,Models,Logic,Format}`, `Fuel/DesignSystem`,
  `Fuel/Features/<Feature>`, `Fuel/Resources`. Tests in `FuelTests/`.
- `Core/Logic` is pure Foundation (no SwiftUI/Supabase imports) and unit-tested.
- Backend: Express API (`{ data }` envelope, camelCase; errors `{ error: { message } }`) via
  `APIClient`; personal meal log via supabase-swift `SupabaseClient` (PostgREST, snake_case
  CodingKeys, client-generated UUIDs). Config from `AppConfig` (Info.plist-injected xcconfig).
- User-facing strings: `String(localized:)` / string-catalog keys from day one (en + ar ship in M6
  but keys are written as we go). No force unwraps outside tests; errors surface through a shared
  presentable-error pattern, not `print`.

## Verification (run before declaring any milestone done)

```sh
cd /Users/omarstate/Fuel/ios
xcodebuild -project Fuel.xcodeproj -scheme Fuel \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build        # must be clean
xcodebuild -project Fuel.xcodeproj -scheme Fuel \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet test         # when tests exist
```

Local backend for manual flows: `cd /Users/omarstate/Fuel/backend && npm run dev` (port 4000).
The app's Debug config points at `http://localhost:4000/api`; Supabase is the live project.
