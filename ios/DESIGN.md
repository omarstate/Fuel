# Fuel iOS — Design System & Engineering Conventions

Read this fully before writing any code. Every screen must feel like the same app.
The bar is: **a polished, professional iOS 26 app** — Liquid Glass, seamless, fast, obvious.

## Product identity

Fuel is a nutrition tracker (Egypt-first food data, AI assisted). The identity is **light-only** —
a warm cream, editorial canvas carrying opaque cream-white cards, ported from the web app's light
editorial surface. The app locks to light via `.preferredColorScheme(.light)` on `RootView`, so every
color set is scheme-independent (a single universal value renders identically light/dark).

| Token (asset catalog name) | Value | Use |
|---|---|---|
| `FuelBackground` | `#F7F3EA` warm cream | screen background (web `--background`) |
| `FuelSurface` | `#FFFDF7` cream-white | the opaque card fill + solid grouped list rows (web `--card`) |
| `FuelInk` | `#14120F` warm near-black | primary text; also every hairline/track, at 6–8% opacity |
| `FuelSubtle` | `#6F6A5C` warm gray | secondary text |
| `FuelVolt` | `#3AA35B` green | brand accent FILL — primary buttons, plus disc, selection, progress fills |
| `FuelVoltInk` | `#2E8044` green | brand green **text/icons/thin strokes** (links, active tab, "+N burned", the global `.tint`) |
| `FuelOlive` | `#3AA35B` green | the LARGE green fill (protein bar, lunch segment, on-target chart bars). Same green as volt |
| `FuelOver` | `#C85A3C` terracotta | over-target signal, the **fat** fill and the snack section. Warm, never alarm red |
| `FuelOverInk` | `#AD4A30` terracotta | terracotta **text/icons** (over-goal pace line, over pills) |
| `FuelCitrus` | `#3AA35B` green | **historical name — the green brand accent.** Kept so the many accent call-sites (button tints, links, active states) re-point without edits. NOT protein |
| `FuelCitrusInk` | `#2E8044` green | green brand accent ink (same role as `FuelVoltInk`) |
| `FuelBlue` | `#3D6FD1` blue | the **dinner** section fill |
| `FuelBlueInk` | `#315CB0` blue | blue text/icons |
| `FuelGold` / `FuelGoldInk` | `#CE9440` / `#A9741F` | carbs + breakfast + streak fill / ink |
| `FuelDestructive` | `#C0392B` | delete/danger |

Define all as color sets in `Fuel/Resources/Assets.xcassets` (asset symbol generation is off — the
`Color.fuelVolt` extensions in `DesignSystem/FuelColors.swift` ARE the API). Never hardcode hex in
views (the only exceptions are the full-screen camera overlay in `BarcodeScanView`, which is
black/white over a live feed).

**Fill vs ink is load-bearing on cream.** A saturated fill (`FuelVolt`, `FuelOver`, `FuelGold`) is
readable as a bar, a dot or a disc, and *not* readable as small text — small text and icons always
take the `*Ink` variant. That includes the global `.tint`, which colors system text.

Macro color convention (matches the light editorial mockup): **protein = green**
(`FuelOlive` / `FuelVoltInk`), **carbs = gold** (`FuelGold` / `FuelGoldInk`), **fat = terracotta**
(`FuelOver` / `FuelOverInk`), and **calories = green** (`FuelOlive`) — all via `MacroPalette`.
Meal sections have their own key, `MealTypePalette`: **breakfast gold, lunch green, dinner blue,
snack terracotta**, shared by the Today section-card dots and the hero's stacked bar so the two read
as one legend. Progress bars NEVER turn red when over target — they keep their color and clamp at
100%; "over" is signalled by the pace line / pills in `FuelOver`/`FuelOverInk`. `FuelDestructive` is
reserved exclusively for destructive actions.

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

## Shape & surfaces — opaque cream cards

- **Corner radius:** cards/surfaces use **22pt** continuous corners (`FuelRadius.card`); small
  elements (inputs, chips) use **12pt** (`FuelRadius.small`).
- **Cards are opaque, not glass:** use the `.fuelCard()` modifier — a `Color.fuelSurface` fill in a
  22pt continuous shape, a hairline `Color.fuelInk.opacity(0.06)` edge, and one soft drop shadow
  (`.black.opacity(0.05)`, radius 14, y 5). On cream the separation comes from the shadow, not from
  a material. `.fuelCard(in: someShape)` applies the same recipe to another silhouette (the Today
  quick-add pills).
- Glass is reserved for the **floating layer** — the bottom bar, chips, buttons, scanner controls.
  Content never sits on glass.
- Solid grouped list rows still use `Color.fuelSurface` via `.listRowBackground(...)`.
- `ActivityRings` is retained but **unused** — the Today hero is now the "LEFT TO EAT" card below.

## The Today screen

A `ScrollView` + `LazyVStack` (16pt gutters) on `FuelBackground`, not a `List` — top to bottom:

1. **Header**, bare on the canvas: the date eyebrow, a gold-dot streak pill on the right, and a
   time-of-day greeting in `.fuelMasthead` ("Morning, Omar" — first name from the auth display name).
2. **"LEFT TO EAT" hero card** — the remaining-kcal number at 52pt, "N eaten" and Health's
   "+N burned" stacked beside it, a 10pt progress bar **segmented by meal section** (colors from
   `MealTypePalette`; it rescales to consumed once over goal, so going over compresses rather than
   overflows), and a plain-language pace line + `goal N`.
3. **Three macro tiles** (protein / carbs / fat), each with a 4pt bar in its `MacroPalette` fill.
4. **Quick add** — up to two pill cards for the meals this user repeats most (≥2 logs in 30 days,
   not already eaten today). One tap logs straight into the section the clock suggests.
5. **One collapsible card per meal section** — colored dot, name, "2 items · 1:15 PM", kcal subtotal.
   Filled sections expand in place to their `MealRow`s plus a "+ Add"; empty ones are a direct
   "Add" into `AddMealPanel`. Swipe-to-delete went away with the `List`; the row's trash button and
   its long-press menu both still route through the confirmation dialog.

**Burned calories come from HealthKit** (`Core/Health/HealthService.swift`): read-only, active energy
only, `HKStatisticsQuery` cumulative sum since local midnight. Every failure path — Health absent,
permission denied, query error — returns 0, and the fetch sits outside the throwing group in
`TodayViewModel.refresh()` so it can never delay or fail the meal load. The entitlement lives in
`Config/Fuel.entitlements` (wired via `CODE_SIGN_ENTITLEMENTS` in `Config/Shared.xcconfig`) and the
usage string in `Config/Info.plist` + `Resources/InfoPlist.xcstrings`.

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
3. **Content cards are NOT glass.** On the cream canvas, `.fuelCard()` is an opaque `FuelSurface`
   fill with a hairline and a soft shadow — frosted panels turn muddy over a light background.
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
  remaining kcal, the section-stacked bar, the pace line. Detail lives one tap deeper (sections
  start collapsed). Detail lives one tap deeper.

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
