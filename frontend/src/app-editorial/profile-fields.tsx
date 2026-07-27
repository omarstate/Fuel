import * as React from "react"
import { Input } from "@/components/ui/input"
import { Field, FieldGroup, FieldLabel } from "@/components/ui/field"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  ACTIVITY_OPTIONS,
  PACE_OPTIONS,
  computeTargets,
  type ActivityLevel,
  type Pace,
  type ProfileInput,
  type Sex,
  type Targets,
} from "@/lib/nutrition"
import { useI18n } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/en"

// Draft form state — string inputs so fields can be empty while the user is
// mid-edit, without coercing to 0/NaN.
export type ProfileFormState = {
  sex: Sex | ""
  age: string
  heightCm: string
  weightKg: string
  goalWeightKg: string
  activityLevel: ActivityLevel | ""
  pace: Pace | ""
}

export const emptyProfileForm: ProfileFormState = {
  sex: "",
  age: "",
  heightCm: "",
  weightKg: "",
  goalWeightKg: "",
  activityLevel: "",
  pace: "",
}

// Ranges must match backend/src/validators/profile.validator.js exactly.
export function validateProfileForm(form: ProfileFormState): ProfileInput | null {
  const age = Number(form.age)
  const heightCm = Number(form.heightCm)
  const weightKg = Number(form.weightKg)
  const goalWeightKg = Number(form.goalWeightKg)

  if (!form.sex || !form.activityLevel || !form.pace) return null
  if (!Number.isFinite(age) || age < 13 || age > 120) return null
  if (!Number.isFinite(heightCm) || heightCm < 90 || heightCm > 260) return null
  if (!Number.isFinite(weightKg) || weightKg < 30 || weightKg > 400) return null
  if (!Number.isFinite(goalWeightKg) || goalWeightKg < 30 || goalWeightKg > 400) return null

  return {
    sex: form.sex,
    age,
    heightCm,
    weightKg,
    goalWeightKg,
    activityLevel: form.activityLevel,
    pace: form.pace,
  }
}

/** Live preview of the computed daily target, or null while the form is incomplete/invalid. */
export function usePreviewTargets(form: ProfileFormState): Targets | null {
  return React.useMemo(() => {
    const input = validateProfileForm(form)
    return input ? computeTargets(input) : null
  }, [form])
}

export function TargetPreview({ targets }: { targets: Targets | null }) {
  const { t, formatNumber } = useI18n()
  return (
    <div className="rounded-xl border border-border bg-[var(--accent-tint)] p-4">
      <div className="font-mono text-[0.65rem] uppercase tracking-[0.16em] text-[var(--accent-ink)]">
        {t("profile.yourDailyTarget")}
      </div>
      {targets ? (
        <p className="mt-1.5 text-sm text-foreground">
          <span className="font-mono font-semibold">{formatNumber(targets.calories)}</span>{" "}
          {t("common.kcal")} ·{" "}
          <span className="font-mono font-semibold">{formatNumber(targets.protein)}</span> {t("profile.gProtein")} ·{" "}
          <span className="font-mono font-semibold">{formatNumber(targets.carbs)}</span> {t("profile.gCarbs")} ·{" "}
          <span className="font-mono font-semibold">{formatNumber(targets.fat)}</span> {t("profile.gFat")}
        </p>
      ) : (
        <p className="mt-1.5 text-sm text-muted-foreground">
          {t("profile.fillToSeeTarget")}
        </p>
      )}
    </div>
  )
}

export function ProfileFields({
  form,
  onChange,
}: {
  form: ProfileFormState
  onChange: (next: ProfileFormState) => void
}) {
  const { t } = useI18n()

  function update<K extends keyof ProfileFormState>(key: K, value: ProfileFormState[K]) {
    onChange({ ...form, [key]: value })
  }

  return (
    <FieldGroup>
      <Field>
        <FieldLabel>{t("profile.sex")}</FieldLabel>
        <ToggleGroup
          type="single"
          variant="outline"
          value={form.sex}
          onValueChange={(v) => v && update("sex", v as Sex)}
          className="w-full"
        >
          <ToggleGroupItem value="male" className="h-11 flex-1 text-sm">
            {t("profile.male")}
          </ToggleGroupItem>
          <ToggleGroupItem value="female" className="h-11 flex-1 text-sm">
            {t("profile.female")}
          </ToggleGroupItem>
        </ToggleGroup>
      </Field>

      <div className="grid grid-cols-2 gap-4">
        <Field>
          <FieldLabel htmlFor="profile-age">{t("profile.age")}</FieldLabel>
          <Input
            id="profile-age"
            type="number"
            inputMode="numeric"
            min={13}
            max={120}
            placeholder="28"
            className="h-11"
            value={form.age}
            onChange={(e) => update("age", e.target.value)}
          />
        </Field>
        <Field>
          <FieldLabel htmlFor="profile-height">{t("profile.heightCm")}</FieldLabel>
          <Input
            id="profile-height"
            type="number"
            inputMode="decimal"
            min={90}
            max={260}
            placeholder="178"
            className="h-11"
            value={form.heightCm}
            onChange={(e) => update("heightCm", e.target.value)}
          />
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field>
          <FieldLabel htmlFor="profile-weight">{t("profile.weightKg")}</FieldLabel>
          <Input
            id="profile-weight"
            type="number"
            inputMode="decimal"
            min={30}
            max={400}
            placeholder="80"
            className="h-11"
            value={form.weightKg}
            onChange={(e) => update("weightKg", e.target.value)}
          />
        </Field>
        <Field>
          <FieldLabel htmlFor="profile-goal-weight">{t("profile.goalWeightKg")}</FieldLabel>
          <Input
            id="profile-goal-weight"
            type="number"
            inputMode="decimal"
            min={30}
            max={400}
            placeholder="75"
            className="h-11"
            value={form.goalWeightKg}
            onChange={(e) => update("goalWeightKg", e.target.value)}
          />
        </Field>
      </div>

      <Field>
        <FieldLabel htmlFor="profile-activity">{t("profile.activityLevel")}</FieldLabel>
        <Select
          value={form.activityLevel}
          onValueChange={(v) => update("activityLevel", v as ActivityLevel)}
        >
          <SelectTrigger id="profile-activity" className="h-11 w-full">
            <SelectValue placeholder={t("profile.chooseActivity")} />
          </SelectTrigger>
          <SelectContent>
            <SelectGroup>
              {ACTIVITY_OPTIONS.map((opt) => (
                <SelectItem key={opt.value} value={opt.value}>
                  {t(`activity.${opt.value}` as MessageKey)}
                  <span className="ms-1.5 text-muted-foreground">
                    — {t(`activity.${opt.value}.hint` as MessageKey)}
                  </span>
                </SelectItem>
              ))}
            </SelectGroup>
          </SelectContent>
        </Select>
      </Field>

      <Field>
        <FieldLabel>{t("profile.pace")}</FieldLabel>
        <ToggleGroup
          type="single"
          variant="outline"
          value={form.pace}
          onValueChange={(v) => v && update("pace", v as Pace)}
          className="w-full"
        >
          {PACE_OPTIONS.map((opt) => (
            <ToggleGroupItem
              key={opt.value}
              value={opt.value}
              className="h-auto flex-1 flex-col gap-0.5 py-3"
            >
              <span className="text-sm font-medium">{t(`pace.${opt.value}` as MessageKey)}</span>
              <span className="text-[0.7rem] text-muted-foreground">
                {t(`pace.${opt.value}.hint` as MessageKey)}
              </span>
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
      </Field>
    </FieldGroup>
  )
}
