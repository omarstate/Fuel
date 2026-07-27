import { useI18n, type Lang } from "@/lib/i18n"
import { cn } from "@/lib/utils"

const options: { value: Lang; labelKey: "lang.english" | "lang.arabic" }[] = [
  { value: "en", labelKey: "lang.english" },
  { value: "ar", labelKey: "lang.arabic" },
]

/** Small EN / عربي segmented toggle. Matches the editorial pill style used by
 * the sidebar mode switch. Renders whichever surface it's dropped into. */
export function LanguageToggle({ className }: { className?: string }) {
  const { lang, setLang, t } = useI18n()

  return (
    <div
      className={cn(
        "inline-flex rounded-full border border-border bg-secondary p-0.5",
        className
      )}
      role="group"
      aria-label={t("lang.label")}
    >
      {options.map(({ value, labelKey }) => (
        <button
          key={value}
          type="button"
          onClick={() => setLang(value)}
          aria-pressed={lang === value}
          className={cn(
            "rounded-full px-3 py-1 text-xs font-medium transition-colors",
            lang === value
              ? "bg-foreground text-background"
              : "text-muted-foreground hover:text-foreground"
          )}
        >
          {t(labelKey)}
        </button>
      ))}
    </div>
  )
}

export default LanguageToggle
