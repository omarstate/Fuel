import * as React from "react"
import { motion } from "framer-motion"
import { useNavigate } from "react-router-dom"
import { toast } from "sonner"
import { User } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Field, FieldLabel } from "@/components/ui/field"
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { deleteAccount, saveProfile } from "@/lib/api"
import { useAuth } from "@/lib/auth"
import { useMe } from "@/app-editorial/use-me"
import { useI18n } from "@/lib/i18n"
import { LanguageToggle } from "@/components/language-toggle"
import {
  ProfileFields,
  TargetPreview,
  emptyProfileForm,
  usePreviewTargets,
  validateProfileForm,
  type ProfileFormState,
} from "@/app-editorial/profile-fields"
import type { Profile as ProfileData } from "@/lib/api"

const fade = (delay = 0) => ({
  initial: { opacity: 0, y: 12 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.4, delay },
})

function profileToForm(profile: ProfileData): ProfileFormState {
  return {
    sex: profile.sex,
    age: String(profile.age),
    heightCm: String(profile.heightCm),
    weightKg: String(profile.weightKg),
    goalWeightKg: String(profile.goalWeightKg),
    activityLevel: profile.activityLevel,
    pace: profile.pace,
  }
}

export function Profile() {
  const navigate = useNavigate()
  const { t, formatNumber } = useI18n()
  const { user, signOut, updateDisplayName } = useAuth()
  const { profile, targets, refreshProfile } = useMe()

  const savedName = ((user?.user_metadata?.display_name as string | undefined) ?? "").trim()
  const [name, setName] = React.useState(savedName)
  const [form, setForm] = React.useState<ProfileFormState>(
    profile ? profileToForm(profile) : emptyProfileForm
  )
  const [submitting, setSubmitting] = React.useState(false)
  const [deleting, setDeleting] = React.useState(false)
  const preview = usePreviewTargets(form)

  React.useEffect(() => {
    if (profile) setForm(profileToForm(profile))
  }, [profile])

  React.useEffect(() => {
    setName(savedName)
  }, [savedName])

  function handleReset() {
    setName(savedName)
    setForm(profile ? profileToForm(profile) : emptyProfileForm)
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    const input = validateProfileForm(form)
    if (!input) return

    setSubmitting(true)
    try {
      if (name.trim() !== savedName) {
        const { error } = await updateDisplayName(name.trim())
        if (error) throw new Error(error)
      }
      await saveProfile(input)
      await refreshProfile()
      toast.success(t("profile.updated"))
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("onboarding.saveFailed"))
    } finally {
      setSubmitting(false)
    }
  }

  async function handleDelete() {
    setDeleting(true)
    try {
      await deleteAccount()
      await signOut()
      toast.success(t("profile.accountDeleted"))
      navigate("/", { replace: true })
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("profile.deleteFailed"))
      setDeleting(false)
    }
  }

  const displayName = name.trim() || savedName || user?.email?.split("@")[0] || t("profile.there")
  const activityLabel = profile ? t(`activity.${profile.activityLevel}`) : ""
  const paceLabel = profile ? t(`pace.${profile.pace}`) : ""

  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-6">
      <motion.header {...fade()} className="flex flex-wrap items-end justify-between gap-4 border-b border-border pb-6">
        <div className="flex flex-col gap-2">
          <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
            {t("nav.account")}
          </div>
          <h1 className="font-heading text-4xl font-semibold tracking-tight text-foreground">
            {t("nav.profile")}
          </h1>
        </div>
        <div className="flex flex-col items-start gap-1.5">
          <span className="font-mono text-[0.6rem] uppercase tracking-[0.16em] text-muted-foreground">
            {t("lang.label")}
          </span>
          <LanguageToggle />
        </div>
      </motion.header>

      <motion.section {...fade(0.05)} className="grid gap-4 lg:grid-cols-3">
        <div className="flex items-center gap-3 rounded-xl border border-border bg-card p-6 lg:col-span-1">
          <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
            <User className="size-5" />
          </span>
          <div>
            <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-muted-foreground">
              {t("profile.currentTarget")}
            </div>
            <div className="mt-1 font-mono text-lg font-semibold text-foreground">
              {formatNumber(targets.calories)} {t("common.kcal")}
            </div>
            <div className="text-sm text-muted-foreground">
              {formatNumber(targets.protein)}g P · {formatNumber(targets.carbs)}g C · {formatNumber(targets.fat)}g F
            </div>
          </div>
        </div>

        {profile && (
          <div className="flex flex-col justify-center gap-1 rounded-xl border border-border bg-card p-6 lg:col-span-2">
            <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-muted-foreground">
              {displayName}
            </div>
            <p className="text-sm text-foreground">
              {profile.sex === "male" ? t("profile.male") : t("profile.female")} ·{" "}
              {t("profile.yrs", { value: formatNumber(profile.age) })} ·{" "}
              {t("profile.cm", { value: formatNumber(profile.heightCm) })} ·{" "}
              {t("profile.kgGoal", {
                value: formatNumber(profile.weightKg),
                goal: formatNumber(profile.goalWeightKg),
              })}
            </p>
            <p className="text-sm text-muted-foreground">
              {activityLabel} · {t("profile.pacePace", { value: paceLabel })}
            </p>
          </div>
        )}
      </motion.section>

      <motion.section {...fade(0.1)} className="flex flex-col gap-4">
        <h2 className="font-heading text-lg font-semibold tracking-tight text-foreground">
          {t("profile.editDetails")}
        </h2>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4 rounded-xl border border-border bg-card p-6">
          <Field>
            <FieldLabel htmlFor="profile-name">{t("profile.name")}</FieldLabel>
            <Input
              id="profile-name"
              type="text"
              autoComplete="name"
              placeholder={t("profile.namePlaceholder")}
              className="h-11"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </Field>

          <TargetPreview targets={preview} />

          <ProfileFields form={form} onChange={setForm} />

          <div className="mt-1 flex justify-end gap-2">
            <Button type="button" variant="outline" onClick={handleReset} disabled={submitting}>
              {t("profile.reset")}
            </Button>
            <Button type="submit" disabled={!preview || submitting}>
              {submitting ? t("common.saving") : t("profile.saveChanges")}
            </Button>
          </div>
        </form>
      </motion.section>

      <motion.section {...fade(0.15)} className="flex flex-col gap-4">
        <h2 className="font-heading text-lg font-semibold tracking-tight text-foreground">
          {t("profile.dangerZone")}
        </h2>
        <div className="flex flex-col gap-4 rounded-xl border border-destructive/30 bg-destructive/5 p-6 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className="text-sm font-medium text-foreground">{t("profile.deleteAccount")}</div>
            <p className="mt-1 max-w-md text-sm text-muted-foreground">
              {t("profile.deleteBlurb")}
            </p>
          </div>
          <Dialog>
            <DialogTrigger asChild>
              <Button variant="destructive" className="shrink-0" disabled={deleting}>
                {t("profile.deleteAccount")}
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-md">
              <DialogHeader>
                <DialogTitle>{t("profile.deleteConfirmTitle")}</DialogTitle>
                <DialogDescription>
                  {t("profile.deleteConfirmBody")}
                </DialogDescription>
              </DialogHeader>
              <DialogFooter>
                <DialogClose asChild>
                  <Button type="button" variant="outline" disabled={deleting}>
                    {t("common.cancel")}
                  </Button>
                </DialogClose>
                <Button
                  type="button"
                  variant="destructive"
                  onClick={handleDelete}
                  disabled={deleting}
                >
                  {deleting ? t("common.deleting") : t("profile.deleteAccount")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>
      </motion.section>
    </div>
  )
}

export default Profile
