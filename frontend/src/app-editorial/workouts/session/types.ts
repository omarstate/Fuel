// Camel-case shapes for the per-user workout session tables, plus the
// snake_case <-> camelCase row mappers. Session data is written directly via
// supabase-js with RLS (see use-*.ts in this folder) — mirrors the pattern in
// app-editorial/use-meals.ts.

export type SessionStatus = "in_progress" | "completed"

export type WorkoutSession = {
  id: string
  userId: string
  categoryId: string | null
  categoryName: string | null
  categorySlug: string | null
  status: SessionStatus
  startedAt: Date
  endedAt: Date | null
  durationSeconds: number | null
  notes: string | null
  createdAt: Date
}

export type SessionSet = {
  id: string
  sessionExerciseId: string
  userId: string
  setNumber: number
  weight: number | null
  reps: number | null
  note: string | null
  createdAt: Date
}

export type SessionExercise = {
  id: string
  sessionId: string
  userId: string
  workoutId: string | null
  name: string
  position: number
  createdAt: Date
}

export type SessionExerciseWithSets = SessionExercise & { sets: SessionSet[] }

export type SessionWithExercises = WorkoutSession & {
  exercises: SessionExerciseWithSets[]
}

/** A completed session enriched with counts, for the history list. */
export type HistorySession = WorkoutSession & {
  exerciseCount: number
  setCount: number
}

// ---------------------------------------------------------------------------
// Row shapes (as they come back from supabase-js)
// ---------------------------------------------------------------------------

export type WorkoutSessionRow = {
  id: string
  user_id: string
  category_id: string | null
  category_name: string | null
  category_slug: string | null
  status: SessionStatus
  started_at: string
  ended_at: string | null
  duration_seconds: number | null
  notes: string | null
  created_at: string
}

export type SessionSetRow = {
  id: string
  session_exercise_id: string
  user_id: string
  set_number: number
  weight: number | string | null
  reps: number | null
  note: string | null
  created_at: string
}

export type SessionExerciseRow = {
  id: string
  session_id: string
  user_id: string
  workout_id: string | null
  name: string
  position: number
  created_at: string
}

export type SessionExerciseWithSetsRow = SessionExerciseRow & {
  session_sets: SessionSetRow[] | null
}

export type WorkoutSessionWithNestedRow = WorkoutSessionRow & {
  session_exercises: SessionExerciseWithSetsRow[] | null
}

export function rowToSession(row: WorkoutSessionRow): WorkoutSession {
  return {
    id: row.id,
    userId: row.user_id,
    categoryId: row.category_id,
    categoryName: row.category_name,
    categorySlug: row.category_slug,
    status: row.status,
    startedAt: new Date(row.started_at),
    endedAt: row.ended_at ? new Date(row.ended_at) : null,
    durationSeconds: row.duration_seconds,
    notes: row.notes,
    createdAt: new Date(row.created_at),
  }
}

export function rowToSessionSet(row: SessionSetRow): SessionSet {
  return {
    id: row.id,
    sessionExerciseId: row.session_exercise_id,
    userId: row.user_id,
    setNumber: row.set_number,
    weight: row.weight === null ? null : Number(row.weight),
    reps: row.reps,
    note: row.note,
    createdAt: new Date(row.created_at),
  }
}

export function rowToSessionExercise(row: SessionExerciseRow): SessionExercise {
  return {
    id: row.id,
    sessionId: row.session_id,
    userId: row.user_id,
    workoutId: row.workout_id,
    name: row.name,
    position: row.position,
    createdAt: new Date(row.created_at),
  }
}

/** Maps a nested `workout_sessions` row (with session_exercises/session_sets
 * embedded) into the camelCase shape, sorting exercises by position and each
 * exercise's sets by set_number. */
export function rowToSessionWithExercises(
  row: WorkoutSessionWithNestedRow
): SessionWithExercises {
  const exercises = (row.session_exercises ?? [])
    .slice()
    .sort((a, b) => a.position - b.position)
    .map((ex) => ({
      ...rowToSessionExercise(ex),
      sets: (ex.session_sets ?? [])
        .slice()
        .sort((a, b) => a.set_number - b.set_number)
        .map(rowToSessionSet),
    }))

  return { ...rowToSession(row), exercises }
}
