import * as React from "react"
import { Direction } from "radix-ui"
import { en, type MessageKey } from "./en"
import { ar } from "./ar"

export type Lang = "en" | "ar"

const dictionaries: Record<Lang, Record<MessageKey, string>> = { en, ar }

const STORAGE_KEY = "fuel.lang"

function initialLang(): Lang {
  if (typeof window === "undefined") return "en"
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY)
    if (stored === "en" || stored === "ar") return stored
  } catch {
    // localStorage may be unavailable (private mode) — fall through.
  }
  if (typeof navigator !== "undefined" && navigator.language?.startsWith("ar")) {
    return "ar"
  }
  return "en"
}

/** Replace `{name}` placeholders in a template with the matching var value. */
function interpolate(template: string, vars?: Record<string, string | number>): string {
  if (!vars) return template
  return template.replace(/\{(\w+)\}/g, (match, key: string) =>
    key in vars ? String(vars[key]) : match
  )
}

// Map ASCII digits to Eastern Arabic-Indic digits (٠-٩).
const ARABIC_DIGITS = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"] as const

function toArabicDigits(input: string): string {
  return input.replace(/[0-9]/g, (d) => ARABIC_DIGITS[Number(d)])
}

export type I18nContextValue = {
  lang: Lang
  setLang: (lang: Lang) => void
  dir: "ltr" | "rtl"
  t: (key: MessageKey, vars?: Record<string, string | number>) => string
  tp: (baseKey: string, count: number, vars?: Record<string, string | number>) => string
  formatNumber: (n: number, opts?: Intl.NumberFormatOptions) => string
  formatDate: (d: Date | string | number, opts?: Intl.DateTimeFormatOptions) => string
  localizeDigits: (s: string) => string
}

const I18nContext = React.createContext<I18nContextValue | null>(null)

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLangState] = React.useState<Lang>(initialLang)

  const dir: "ltr" | "rtl" = lang === "ar" ? "rtl" : "ltr"

  React.useEffect(() => {
    const root = document.documentElement
    root.lang = lang
    root.dir = dir
    try {
      window.localStorage.setItem(STORAGE_KEY, lang)
    } catch {
      // Ignore persistence failures.
    }
  }, [lang, dir])

  const setLang = React.useCallback((next: Lang) => setLangState(next), [])

  const value = React.useMemo<I18nContextValue>(() => {
    const localeTag = lang === "ar" ? "ar-EG" : "en-US"
    const dict = dictionaries[lang]

    const t = (key: MessageKey, vars?: Record<string, string | number>) => {
      const template = dict[key] ?? en[key] ?? key
      return interpolate(template, vars)
    }

    const pluralRules = new Intl.PluralRules(lang)
    const tp = (baseKey: string, count: number, vars?: Record<string, string | number>) => {
      const rule = pluralRules.select(count)
      const primary = `${baseKey}.${rule}` as MessageKey
      const other = `${baseKey}.other` as MessageKey
      const template = dict[primary] ?? dict[other] ?? en[primary] ?? en[other] ?? baseKey
      return interpolate(template, { count, ...vars })
    }

    const formatNumber = (n: number, opts?: Intl.NumberFormatOptions) =>
      n.toLocaleString(localeTag, opts)

    const formatDate = (d: Date | string | number, opts?: Intl.DateTimeFormatOptions) =>
      new Date(d).toLocaleDateString(localeTag, opts)

    const localizeDigits = (s: string) => (lang === "ar" ? toArabicDigits(s) : s)

    return { lang, setLang, dir, t, tp, formatNumber, formatDate, localizeDigits }
  }, [lang, dir, setLang])

  return (
    <I18nContext.Provider value={value}>
      <Direction.Provider dir={dir}>{children}</Direction.Provider>
    </I18nContext.Provider>
  )
}

export function useI18n(): I18nContextValue {
  const ctx = React.useContext(I18nContext)
  if (!ctx) {
    throw new Error("useI18n must be used within a LanguageProvider")
  }
  return ctx
}
