import * as React from "react"
import {
  getCategories,
  getMealsPaged,
  type Category,
  type CatalogMeal,
} from "@/lib/api"

const CACHE_TTL_MS = 5 * 60 * 1000

// ---------------------------------------------------------------------------
// Module-level meal cache. Keyed by `${category}|${search}` (the accumulated
// list for a given filter, however many "Show more" pages deep the user went).
// Hydrated instantly on mount/param change when younger than the TTL; the
// fetch is skipped entirely in that case. Cleared by invalidateMealsCache()
// after any create/edit/delete/AI-create so the next read is fresh.
// ---------------------------------------------------------------------------
type MealsCacheEntry = { at: number; meals: CatalogMeal[]; count: number }
const mealsCache = new Map<string, MealsCacheEntry>()

function cacheKey(category: string | undefined, search: string): string {
  return `${category ?? ""}|${search ?? ""}`
}

export function invalidateMealsCache(): void {
  mealsCache.clear()
}

// ---------------------------------------------------------------------------
// Categories cache — tiny, shared, same 5-minute TTL.
// ---------------------------------------------------------------------------
let categoriesCache: { at: number; categories: Category[] } | null = null

export function useCachedCategories(): {
  categories: Category[]
  loading: boolean
} {
  const [categories, setCategories] = React.useState<Category[]>(
    () => categoriesCache?.categories ?? []
  )
  const [loading, setLoading] = React.useState(
    () => !(categoriesCache && Date.now() - categoriesCache.at < CACHE_TTL_MS)
  )

  React.useEffect(() => {
    if (categoriesCache && Date.now() - categoriesCache.at < CACHE_TTL_MS) {
      setCategories(categoriesCache.categories)
      setLoading(false)
      return
    }
    let active = true
    setLoading(true)
    getCategories()
      .then((cats) => {
        if (!active) return
        categoriesCache = { at: Date.now(), categories: cats }
        setCategories(cats)
      })
      .catch(() => {
        // Non-fatal: chips just won't render. Leave whatever we had.
      })
      .finally(() => {
        if (active) setLoading(false)
      })
    return () => {
      active = false
    }
  }, [])

  return { categories, loading }
}

export type UsePagedMeals = {
  meals: CatalogMeal[]
  count: number
  loading: boolean
  loadingMore: boolean
  error: string | null
  hasMore: boolean
  loadMore: () => void
  refresh: () => void
}

export function usePagedMeals({
  category,
  search = "",
  pageSize = 9,
}: {
  category?: string
  search?: string
  pageSize?: number
}): UsePagedMeals {
  const [debouncedSearch, setDebouncedSearch] = React.useState(search)
  const [meals, setMeals] = React.useState<CatalogMeal[]>([])
  const [count, setCount] = React.useState(0)
  const [loading, setLoading] = React.useState(true)
  const [loadingMore, setLoadingMore] = React.useState(false)
  const [error, setError] = React.useState<string | null>(null)

  // Stale-response guard: only the latest request may write state.
  const requestIdRef = React.useRef(0)
  const loadingMoreRef = React.useRef(false)

  // Debounce the search term (fetch fires on the debounced value).
  React.useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(search), 300)
    return () => clearTimeout(timer)
  }, [search])

  const fetchFirstPage = React.useCallback(
    async (cat: string | undefined, term: string, force: boolean) => {
      const key = cacheKey(cat, term)

      if (!force) {
        const cached = mealsCache.get(key)
        if (cached && Date.now() - cached.at < CACHE_TTL_MS) {
          setMeals(cached.meals)
          setCount(cached.count)
          setError(null)
          setLoading(false)
          return
        }
      }

      const requestId = requestIdRef.current + 1
      requestIdRef.current = requestId
      setLoading(true)
      setError(null)
      try {
        const res = await getMealsPaged({
          category: cat,
          search: term || undefined,
          limit: pageSize,
          offset: 0,
        })
        if (requestIdRef.current !== requestId) return
        mealsCache.set(key, { at: Date.now(), meals: res.meals, count: res.count })
        setMeals(res.meals)
        setCount(res.count)
      } catch (err) {
        if (requestIdRef.current !== requestId) return
        setError(err instanceof Error ? err.message : "Something went wrong.")
      } finally {
        if (requestIdRef.current === requestId) setLoading(false)
      }
    },
    [pageSize]
  )

  React.useEffect(() => {
    fetchFirstPage(category, debouncedSearch, false)
  }, [category, debouncedSearch, fetchFirstPage])

  const loadMore = React.useCallback(() => {
    if (loadingMoreRef.current) return
    loadingMoreRef.current = true

    const key = cacheKey(category, debouncedSearch)
    const requestId = requestIdRef.current + 1
    requestIdRef.current = requestId
    setLoadingMore(true)

    // `meals.length` is captured fresh via the functional set below.
    setMeals((current) => {
      const offset = current.length
      void (async () => {
        try {
          const res = await getMealsPaged({
            category,
            search: debouncedSearch || undefined,
            limit: pageSize,
            offset,
          })
          if (requestIdRef.current !== requestId) return
          setMeals((prev) => {
            const next = [...prev, ...res.meals]
            mealsCache.set(key, { at: Date.now(), meals: next, count: res.count })
            return next
          })
          setCount(res.count)
        } catch (err) {
          if (requestIdRef.current !== requestId) return
          setError(err instanceof Error ? err.message : "Something went wrong.")
        } finally {
          if (requestIdRef.current === requestId) setLoadingMore(false)
          loadingMoreRef.current = false
        }
      })()
      return current
    })
  }, [category, debouncedSearch, pageSize])

  const refresh = React.useCallback(() => {
    fetchFirstPage(category, debouncedSearch, true)
  }, [category, debouncedSearch, fetchFirstPage])

  const hasMore = meals.length < count

  return {
    meals,
    count,
    loading,
    loadingMore,
    error,
    hasMore,
    loadMore,
    refresh,
  }
}
