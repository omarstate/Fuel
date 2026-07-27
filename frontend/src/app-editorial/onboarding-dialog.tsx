import * as React from "react"
import { toast } from "sonner"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { saveProfile } from "@/lib/api"
import { useMe } from "@/app-editorial/use-me"
import { useI18n } from "@/lib/i18n"
import {
  ProfileFields,
  TargetPreview,
  emptyProfileForm,
  usePreviewTargets,
  validateProfileForm,
  type ProfileFormState,
} from "@/app-editorial/profile-fields"

export function OnboardingDialog() {
  const { needsOnboarding, refreshProfile } = useMe()
  const { t } = useI18n()
  const [form, setForm] = React.useState<ProfileFormState>(emptyProfileForm)
  const [submitting, setSubmitting] = React.useState(false)
  const preview = usePreviewTargets(form)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    const input = validateProfileForm(form)
    if (!input) return

    setSubmitting(true)
    try {
      await saveProfile(input)
      await refreshProfile()
      toast.success(t("onboarding.targetsSet"))
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("onboarding.saveFailed"))
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <Dialog open={needsOnboarding}>
      <DialogContent
        showCloseButton={false}
        className="sm:max-w-md"
        onEscapeKeyDown={(e) => e.preventDefault()}
        onInteractOutside={(e) => e.preventDefault()}
      >
        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <DialogHeader>
            <div className="font-mono text-[0.65rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
              {t("onboarding.welcome")}
            </div>
            <DialogTitle>{t("onboarding.title")}</DialogTitle>
            <DialogDescription>
              {t("onboarding.description")}
            </DialogDescription>
          </DialogHeader>

          <TargetPreview targets={preview} />

          <ProfileFields form={form} onChange={setForm} />

          <Button type="submit" disabled={!preview || submitting} className="mt-1 h-10">
            {submitting ? t("common.saving") : t("onboarding.saveContinue")}
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  )
}

export default OnboardingDialog
