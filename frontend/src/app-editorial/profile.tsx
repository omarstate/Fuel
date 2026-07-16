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
import { ACTIVITY_OPTIONS, PACE_OPTIONS } from "@/lib/nutrition"
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
      toast.success("Profile updated.")
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Couldn't save your profile.")
    } finally {
      setSubmitting(false)
    }
  }

  async function handleDelete() {
    setDeleting(true)
    try {
      await deleteAccount()
      await signOut()
      toast.success("Your account has been deleted.")
      navigate("/", { replace: true })
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Couldn't delete your account.")
      setDeleting(false)
    }
  }

  const displayName = name.trim() || savedName || user?.email?.split("@")[0] || "there"
  const activityLabel = ACTIVITY_OPTIONS.find((o) => o.value === profile?.activityLevel)?.label
  const paceLabel = PACE_OPTIONS.find((o) => o.value === profile?.pace)?.label

  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-6">
      <motion.header {...fade()} className="flex flex-col gap-2 border-b border-border pb-6">
        <div className="font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--accent-ink)]">
          Account
        </div>
        <h1 className="font-heading text-4xl font-semibold tracking-tight text-foreground">
          Profile
        </h1>
      </motion.header>

      <motion.section {...fade(0.05)} className="grid gap-4 lg:grid-cols-3">
        <div className="flex items-center gap-3 rounded-xl border border-border bg-card p-6 lg:col-span-1">
          <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-[var(--accent-tint)] text-[var(--accent-ink)]">
            <User className="size-5" />
          </span>
          <div>
            <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-muted-foreground">
              Current target
            </div>
            <div className="mt-1 font-mono text-lg font-semibold text-foreground">
              {targets.calories.toLocaleString()} kcal
            </div>
            <div className="text-sm text-muted-foreground">
              {targets.protein}g P · {targets.carbs}g C · {targets.fat}g F
            </div>
          </div>
        </div>

        {profile && (
          <div className="flex flex-col justify-center gap-1 rounded-xl border border-border bg-card p-6 lg:col-span-2">
            <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-muted-foreground">
              {displayName}
            </div>
            <p className="text-sm text-foreground">
              {profile.sex === "male" ? "Male" : "Female"} · {profile.age} yrs ·{" "}
              {profile.heightCm} cm · {profile.weightKg} kg (goal {profile.goalWeightKg} kg)
            </p>
            <p className="text-sm text-muted-foreground">
              {activityLabel} · {paceLabel} pace
            </p>
          </div>
        )}
      </motion.section>

      <motion.section {...fade(0.1)} className="flex flex-col gap-4">
        <h2 className="font-heading text-lg font-semibold tracking-tight text-foreground">
          Edit your details
        </h2>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4 rounded-xl border border-border bg-card p-6">
          <Field>
            <FieldLabel htmlFor="profile-name">Name</FieldLabel>
            <Input
              id="profile-name"
              type="text"
              autoComplete="name"
              placeholder="What should we call you?"
              className="h-11"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </Field>

          <TargetPreview targets={preview} />

          <ProfileFields form={form} onChange={setForm} />

          <div className="mt-1 flex justify-end gap-2">
            <Button type="button" variant="outline" onClick={handleReset} disabled={submitting}>
              Reset
            </Button>
            <Button type="submit" disabled={!preview || submitting}>
              {submitting ? "Saving…" : "Save changes"}
            </Button>
          </div>
        </form>
      </motion.section>

      <motion.section {...fade(0.15)} className="flex flex-col gap-4">
        <h2 className="font-heading text-lg font-semibold tracking-tight text-foreground">
          Danger zone
        </h2>
        <div className="flex flex-col gap-4 rounded-xl border border-destructive/30 bg-destructive/5 p-6 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className="text-sm font-medium text-foreground">Delete account</div>
            <p className="mt-1 max-w-md text-sm text-muted-foreground">
              Permanently delete your account and all of your data — meals, workouts,
              targets and history. This can't be undone.
            </p>
          </div>
          <Dialog>
            <DialogTrigger asChild>
              <Button variant="destructive" className="shrink-0" disabled={deleting}>
                Delete account
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-md">
              <DialogHeader>
                <DialogTitle>Delete your account?</DialogTitle>
                <DialogDescription>
                  This permanently removes your account and everything in it — meals,
                  workouts, targets and history. This action cannot be undone.
                </DialogDescription>
              </DialogHeader>
              <DialogFooter>
                <DialogClose asChild>
                  <Button type="button" variant="outline" disabled={deleting}>
                    Cancel
                  </Button>
                </DialogClose>
                <Button
                  type="button"
                  variant="destructive"
                  onClick={handleDelete}
                  disabled={deleting}
                >
                  {deleting ? "Deleting…" : "Delete account"}
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
