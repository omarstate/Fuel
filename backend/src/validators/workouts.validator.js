import { z } from "zod"

export const createWorkoutSchema = z.object({
  name: z.string().trim().min(1, "name is required"),
  description: z.string().trim().optional(),
  categoryIds: z.array(z.string().uuid()).min(1, "pick at least one category"),
  primaryMuscle: z.string().trim().optional(),
  equipment: z.string().trim().optional(),
  targetSets: z.number().int().positive().optional(),
  targetReps: z.string().trim().optional(),
})
