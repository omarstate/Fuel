import { motion } from "framer-motion"
import { Link, useLocation, useNavigate } from "react-router-dom"
import { toast } from "sonner"
import {
  Home,
  Utensils,
  Soup,
  GlassWater,
  Dumbbell,
  ListChecks,
  TrendingUp,
  LogOut,
  BookOpen,
  ChefHat,
  ClipboardList,
  History,
} from "lucide-react"
import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupLabel,
  SidebarGroupContent,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarFooter,
  SidebarSeparator,
} from "@/components/ui/sidebar"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { LogoMark } from "@/app-editorial/logo-mark"
import { useMode, type Mode } from "@/components/site/mode-context"
import { editorialAccent, editorialSpark } from "@/app-editorial/theme"
import { useAuth } from "@/lib/auth"
import { cn } from "@/lib/utils"

const nutritionItems = [
  { href: "/dashboard/nutrition", label: "Overview", icon: Home, soon: false },
  { href: "/dashboard/library", label: "Library", icon: BookOpen, soon: false },
  { href: "/dashboard/my-meals", label: "My Meals", icon: ChefHat, soon: false },
  { href: "/dashboard/nutrition/history", label: "History", icon: History, soon: false },
  { href: "/dashboard/nutrition", label: "Recipes", icon: Soup, soon: true },
  { href: "/dashboard/nutrition", label: "Water", icon: GlassWater, soon: true },
]

const workoutItems = [
  { href: "/dashboard/workouts", label: "Overview", icon: Home, soon: false },
  { href: "/dashboard/workouts/library", label: "Library", icon: ListChecks, soon: false },
  { href: "/dashboard/workouts/history", label: "My Workouts", icon: ClipboardList, soon: false },
  { href: "/dashboard/workouts", label: "Progress", icon: TrendingUp, soon: true },
]

const toggleOptions: { value: Mode; label: string; icon: typeof Utensils }[] = [
  { value: "nutrition", label: "Nutrition", icon: Utensils },
  { value: "workouts", label: "Workouts", icon: Dumbbell },
]

function SegmentedModeToggle() {
  const { mode } = useMode()
  const navigate = useNavigate()

  return (
    <div className="flex rounded-full border border-sidebar-border bg-secondary p-1">
      {toggleOptions.map(({ value, label, icon: Icon }) => (
        <button
          key={value}
          type="button"
          onClick={() => navigate(`/dashboard/${value}`)}
          className={cn(
            "relative flex-1 rounded-full px-3 py-1.5 text-sm font-medium transition-colors",
            mode === value ? "text-[#14120f]" : "text-muted-foreground"
          )}
        >
          {mode === value && (
            <motion.span
              layoutId="editorial-mode-pill"
              className="absolute inset-0 rounded-full"
              animate={{ backgroundColor: editorialAccent[mode] }}
              transition={{
                layout: { type: "spring", stiffness: 500, damping: 35 },
                backgroundColor: { duration: 0.25 },
              }}
            />
          )}
          <span className="relative z-10 flex items-center justify-center gap-1.5">
            <Icon className="size-3.5" />
            {label}
          </span>
        </button>
      ))}
    </div>
  )
}

export function AppSidebar() {
  const location = useLocation()
  const { mode } = useMode()
  const { user, signOut } = useAuth()
  const spark = editorialSpark[mode]

  const email = user?.email ?? ""
  const name = email ? email.split("@")[0] : "Account"
  const initials = (email.slice(0, 2) || "FU").toUpperCase()

  return (
    <Sidebar collapsible="icon">
      <SidebarHeader className="gap-4 px-2 pt-2">
        <Link to="/editorial" className="flex items-center gap-2.5 px-1">
          <LogoMark
            className="size-7 shrink-0"
            accent={editorialAccent[mode]}
            spark={spark}
          />
          <span className="font-heading text-base font-semibold tracking-tight text-sidebar-foreground group-data-[collapsible=icon]:hidden">
            Fuel
          </span>
        </Link>
        <div className="group-data-[collapsible=icon]:hidden">
          <SegmentedModeToggle />
        </div>
      </SidebarHeader>

      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel className="flex items-center gap-1.5">
            <Utensils className="size-3.5" /> Nutrition
          </SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {nutritionItems.map((item) => (
                <SidebarMenuItem key={item.label}>
                  <SidebarMenuButton
                    asChild
                    isActive={!item.soon && location.pathname === item.href}
                    tooltip={item.label}
                    onClick={(e) => {
                      if (item.soon) {
                        e.preventDefault()
                        toast(`${item.label} is coming soon.`)
                      }
                    }}
                  >
                    <Link to={item.href}>
                      <item.icon />
                      <span>{item.label}</span>
                    </Link>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              ))}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>

        <SidebarGroup>
          <SidebarGroupLabel className="flex items-center gap-1.5">
            <Dumbbell className="size-3.5" /> Workouts
          </SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {workoutItems.map((item) => (
                <SidebarMenuItem key={item.label}>
                  <SidebarMenuButton
                    asChild
                    isActive={!item.soon && location.pathname === item.href}
                    tooltip={item.label}
                    onClick={(e) => {
                      if (item.soon) {
                        e.preventDefault()
                        toast(`${item.label} is coming soon.`)
                      }
                    }}
                  >
                    <Link to={item.href}>
                      <item.icon />
                      <span>{item.label}</span>
                    </Link>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              ))}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>

      <SidebarSeparator />

      <SidebarFooter>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg" onClick={() => signOut()} tooltip="Sign out">
              <Avatar className="size-6">
                <AvatarFallback className="bg-[var(--accent-tint)] text-xs text-[var(--accent-ink)]">
                  {initials}
                </AvatarFallback>
              </Avatar>
              <span className="truncate capitalize">{name}</span>
              <LogOut className="ml-auto size-4 text-muted-foreground" />
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
    </Sidebar>
  )
}
