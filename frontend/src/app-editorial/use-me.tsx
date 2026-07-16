import * as React from "react"
import { useAuth } from "@/lib/auth"
import { getMe, getProfile, type CatalogMeal, type Profile } from "@/lib/api"
import { DEFAULT_TARGETS, type Targets } from "@/lib/nutrition"

type MeContextValue = {
  userId: string | null
  isAdmin: boolean
  loading: boolean
  profile: Profile | null
  targets: Targets
  needsOnboarding: boolean
  refreshProfile: () => Promise<void>
}

const defaultValue: MeContextValue = {
  userId: null,
  isAdmin: false,
  loading: true,
  profile: null,
  targets: DEFAULT_TARGETS,
  needsOnboarding: false,
  refreshProfile: async () => {},
}

const MeContext = React.createContext<MeContextValue>(defaultValue)

export function MeProvider({ children }: { children: React.ReactNode }) {
  const { session } = useAuth()
  const [state, setState] = React.useState<{
    userId: string | null
    isAdmin: boolean
    loading: boolean
    profile: Profile | null
  }>({ userId: null, isAdmin: false, loading: true, profile: null })

  const fetchProfile = React.useCallback(async (): Promise<Profile | null> => {
    try {
      return await getProfile()
    } catch {
      // Quietly fall back to no-profile/defaults on any fetch error.
      return null
    }
  }, [])

  React.useEffect(() => {
    if (!session) {
      setState({ userId: null, isAdmin: false, loading: false, profile: null })
      return
    }

    let active = true
    setState((prev) => ({ ...prev, loading: true }))

    Promise.all([getMe().catch(() => null), fetchProfile()]).then(([me, profile]) => {
      if (!active) return
      setState({
        userId: me?.id ?? session.user?.id ?? null,
        isAdmin: me?.isAdmin ?? false,
        loading: false,
        profile,
      })
    })

    return () => {
      active = false
    }
  }, [session, fetchProfile])

  const refreshProfile = React.useCallback(async () => {
    const profile = await fetchProfile()
    setState((prev) => ({ ...prev, profile }))
  }, [fetchProfile])

  const value = React.useMemo<MeContextValue>(() => {
    const targets: Targets = state.profile
      ? {
          calories: state.profile.targetCalories,
          protein: state.profile.targetProtein,
          carbs: state.profile.targetCarbs,
          fat: state.profile.targetFat,
        }
      : DEFAULT_TARGETS

    return {
      userId: state.userId,
      isAdmin: state.isAdmin,
      loading: state.loading,
      profile: state.profile,
      targets,
      needsOnboarding: !state.loading && !!session && state.profile === null,
      refreshProfile,
    }
  }, [state, session, refreshProfile])

  return <MeContext.Provider value={value}>{children}</MeContext.Provider>
}

export function useMe(): MeContextValue {
  return React.useContext(MeContext)
}

/** Convenience accessor for the current user's daily targets (or the
 * DEFAULT_TARGETS fallback until a profile exists). */
export function useTargets(): Targets {
  return React.useContext(MeContext).targets
}

/** Can the given user edit/delete this catalog meal? Admins can edit anything; */
/** everyone else only their own contributions. */
export function canEditMeal(
  meal: Pick<CatalogMeal, "createdBy">,
  me: { userId: string | null; isAdmin: boolean }
): boolean {
  return me.isAdmin || (!!meal.createdBy && meal.createdBy === me.userId)
}
