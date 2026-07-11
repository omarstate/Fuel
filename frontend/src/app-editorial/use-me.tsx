import * as React from "react"
import { useAuth } from "@/lib/auth"
import { getMe, type CatalogMeal } from "@/lib/api"

type MeContextValue = {
  userId: string | null
  isAdmin: boolean
  loading: boolean
}

const defaultValue: MeContextValue = {
  userId: null,
  isAdmin: false,
  loading: true,
}

const MeContext = React.createContext<MeContextValue>(defaultValue)

export function MeProvider({ children }: { children: React.ReactNode }) {
  const { session } = useAuth()
  const [state, setState] = React.useState<MeContextValue>(defaultValue)

  React.useEffect(() => {
    if (!session) {
      setState({ userId: null, isAdmin: false, loading: false })
      return
    }

    let active = true
    setState((prev) => ({ ...prev, loading: true }))

    getMe()
      .then((me) => {
        if (!active) return
        setState({ userId: me.id, isAdmin: me.isAdmin, loading: false })
      })
      .catch(() => {
        if (!active) return
        // Quietly fall back — still know who's signed in, just not admin status.
        setState({ userId: session.user?.id ?? null, isAdmin: false, loading: false })
      })

    return () => {
      active = false
    }
  }, [session])

  return <MeContext.Provider value={state}>{children}</MeContext.Provider>
}

export function useMe(): MeContextValue {
  return React.useContext(MeContext)
}

/** Can the given user edit/delete this catalog meal? Admins can edit anything; */
/** everyone else only their own contributions. */
export function canEditMeal(
  meal: Pick<CatalogMeal, "createdBy">,
  me: { userId: string | null; isAdmin: boolean }
): boolean {
  return me.isAdmin || (!!meal.createdBy && meal.createdBy === me.userId)
}
