import { Routes, Route, Navigate } from "react-router-dom"
import { MotionConfig } from "framer-motion"
import { TooltipProvider } from "@/components/ui/tooltip"
import { Toaster } from "@/components/ui/sonner"
import { AuthProvider } from "@/lib/auth"
import { RequireAuth } from "@/lib/require-auth"
import { LoginPage } from "@/pages/login"
import { LandingEditorial } from "@/pages/landing-editorial"
import { ToonhubPage } from "@/pages/toonhub"
import { AppShell } from "@/app/app-shell"
import { NutritionHome } from "@/app/nutrition/nutrition-home"
import { WorkoutsHome } from "@/app/workouts/workouts-home"
import { AppShellEditorial } from "@/app-editorial/app-shell"
import { NutritionHome as NutritionHomeEditorial } from "@/app-editorial/nutrition-home"
import Today from "@/app-editorial/today"
import { WorkoutsHome as WorkoutsHomeEditorial } from "@/app-editorial/workouts-home"
import LibraryHome from "@/app-editorial/library/library-home"
import MealDetail from "@/app-editorial/library/meal-detail"
import MyMeals from "@/app-editorial/library/my-meals"
import Profile from "@/app-editorial/profile"
import MealHistory from "@/app-editorial/meal-history"
import WorkoutLibrary from "@/app-editorial/workouts/workout-library"
import SessionActive from "@/app-editorial/workouts/session/session-active"
import SessionHistory from "@/app-editorial/workouts/session/session-history"
import SessionDetail from "@/app-editorial/workouts/session/session-detail"

export function App() {
  return (
    <MotionConfig reducedMotion="user">
      <AuthProvider>
        <TooltipProvider delayDuration={200}>
          <Routes>
            <Route path="/" element={<LandingEditorial />} />
            <Route path="/toonhub" element={<ToonhubPage />} />
            <Route path="/login" element={<LoginPage />} />
            <Route path="/app" element={<AppShell />}>
              <Route index element={<Navigate to="/app/nutrition" replace />} />
              <Route path="nutrition" element={<NutritionHome />} />
              <Route path="workouts" element={<WorkoutsHome />} />
            </Route>
            <Route
              path="/dashboard"
              element={
                <RequireAuth>
                  <AppShellEditorial />
                </RequireAuth>
              }
            >
              <Route index element={<Navigate to="/dashboard/nutrition" replace />} />
              <Route path="nutrition" element={<NutritionHomeEditorial />} />
              <Route path="nutrition/today" element={<Today />} />
              <Route path="nutrition/history" element={<MealHistory />} />
              <Route path="workouts" element={<WorkoutsHomeEditorial />} />
              <Route path="workouts/library" element={<WorkoutLibrary />} />
              <Route path="workouts/history" element={<SessionHistory />} />
              <Route path="workouts/history/:id" element={<SessionDetail />} />
              <Route path="library" element={<LibraryHome />} />
              <Route path="library/:id" element={<MealDetail />} />
              <Route path="my-meals" element={<MyMeals />} />
              <Route path="profile" element={<Profile />} />
            </Route>
            {/* Full-screen active session — outside the shell so there's no
                sidebar; still auth-gated. */}
            <Route
              path="/dashboard/workouts/session/:id"
              element={
                <RequireAuth>
                  <SessionActive />
                </RequireAuth>
              }
            />
          </Routes>
          <Toaster />
        </TooltipProvider>
      </AuthProvider>
    </MotionConfig>
  )
}

export default App
