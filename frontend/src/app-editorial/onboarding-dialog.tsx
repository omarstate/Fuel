import * as React from "react"
import { toast } from "sonner"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { saveProfile } from "@/lib/api"
import { useMe } from "@/app-editorial/use-me"
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
      toast.success("Your targets are set.")
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Couldn't save your profile.")
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
              Welcome to Fuel
            </div>
            <DialogTitle>Let's set your daily target</DialogTitle>
            <DialogDescription>
              A few details so we can calculate a calorie and macro target that fits you.
              You can change these anytime from your profile.
            </DialogDescription>
          </DialogHeader>

          <TargetPreview targets={preview} />

          <ProfileFields form={form} onChange={setForm} />

          <Button type="submit" disabled={!preview || submitting} className="mt-1 h-10">
            {submitting ? "Saving…" : "Save and continue"}
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  )
}

export default OnboardingDialog
