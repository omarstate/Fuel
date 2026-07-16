// snake_case (DB row) -> camelCase (API response)
export const rowToProfile = (row) => ({
  userId: row.user_id,
  sex: row.sex,
  age: row.age,
  heightCm: row.height_cm,
  weightKg: row.weight_kg,
  goalWeightKg: row.goal_weight_kg,
  activityLevel: row.activity_level,
  pace: row.pace,
  targetCalories: row.target_calories,
  targetProtein: row.target_protein,
  targetCarbs: row.target_carbs,
  targetFat: row.target_fat,
  onboardedAt: row.onboarded_at,
  updatedAt: row.updated_at,
})

// camelCase (API request DTO) + computed targets -> snake_case (DB
// insert/upsert row).
export const dtoToRow = (dto, targets) => ({
  sex: dto.sex,
  age: dto.age,
  height_cm: dto.heightCm,
  weight_kg: dto.weightKg,
  goal_weight_kg: dto.goalWeightKg,
  activity_level: dto.activityLevel,
  pace: dto.pace,
  target_calories: targets.targetCalories,
  target_protein: targets.targetProtein,
  target_carbs: targets.targetCarbs,
  target_fat: targets.targetFat,
  updated_at: new Date().toISOString(),
})
