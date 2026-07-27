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
  CalendarCheck,
  ChevronsUpDown,
  UserRound,
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
  useSidebar,
} from "@/components/ui/sidebar"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { LanguageToggle } from "@/components/language-toggle"
import { LogoMark } from "@/app-editorial/logo-mark"
import { useMode, type Mode } from "@/components/site/mode-context"
import { editorialAccent, editorialSpark } from "@/app-editorial/theme"
import { useAuth } from "@/lib/auth"
import { useI18n } from "@/lib/i18n"
import type { MessageKey } from "@/lib/i18n/en"
import { cn } from "@/lib/utils"

const nutritionItems = [
  { href: "/dashboard/nutrition", labelKey: "nav.overview", icon: Home, soon: false },
  { href: "/dashboard/nutrition/today", labelKey: "nav.today", icon: CalendarCheck, soon: false },
  { href: "/dashboard/library", labelKey: "nav.library", icon: BookOpen, soon: false },
  { href: "/dashboard/my-meals", labelKey: "nav.myMeals", icon: ChefHat, soon: false },
  { href: "/dashboard/nutrition/history", labelKey: "nav.history", icon: History, soon: false },
  { href: "/dashboard/nutrition", labelKey: "nav.recipes", icon: Soup, soon: true },
  { href: "/dashboard/nutrition", labelKey: "nav.water", icon: GlassWater, soon: true },
] satisfies { href: string; labelKey: MessageKey; icon: typeof Home; soon: boolean }[]

const workoutItems = [
  { href: "/dashboard/workouts", labelKey: "nav.overview", icon: Home, soon: false },
  { href: "/dashboard/workouts/library", labelKey: "nav.workoutsLibrary", icon: ListChecks, soon: false },
  { href: "/dashboard/workouts/history", labelKey: "nav.myWorkouts", icon: ClipboardList, soon: false },
  { href: "/dashboard/workouts", labelKey: "nav.progress", icon: TrendingUp, soon: true },
] satisfies { href: string; labelKey: MessageKey; icon: typeof Home; soon: boolean }[]

const toggleOptions: { value: Mode; labelKey: MessageKey; icon: typeof Utensils }[] = [
  { value: "nutrition", labelKey: "nav.nutrition", icon: Utensils },
  { value: "workouts", labelKey: "nav.workouts", icon: Dumbbell },
]

function SegmentedModeToggle() {
  const { mode } = useMode()
  const navigate = useNavigate()
  const { setOpenMobile } = useSidebar()
  const { t } = useI18n()

  return (
    <div className="flex rounded-full border border-sidebar-border bg-secondary p-1">
      {toggleOptions.map(({ value, labelKey, icon: Icon }) => (
        <button
          key={value}
          type="button"
          onClick={() => {
            navigate(`/dashboard/${value}`)
            setOpenMobile(false)
          }}
          className={cn(
            "relative flex-1 rounded-full px-3 py-2 text-sm font-medium transition-colors md:py-1.5",
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
            {t(labelKey)}
          </span>
        </button>
      ))}
    </div>
  )
}

export function AppSidebar() {
  const location = useLocation()
  const navigate = useNavigate()
  const { mode } = useMode()
  const { user, signOut } = useAuth()
  const { setOpenMobile } = useSidebar()
  const { t, dir } = useI18n()
  const spark = editorialSpark[mode]

  const email = user?.email ?? ""
  const displayName = (user?.user_metadata?.display_name as string | undefined)?.trim()
  const name = displayName || (email ? email.split("@")[0] : t("nav.account"))
  const initials = (name.slice(0, 2) || "FU").toUpperCase()

  return (
    <Sidebar collapsible="icon" side={dir === "rtl" ? "right" : "left"}>
      <SidebarHeader className="gap-4 px-2 pt-2">
        <Link to="/" className="flex items-center gap-2.5 px-1">
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
            <Utensils className="size-3.5" /> {t("nav.nutrition")}
          </SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {nutritionItems.map((item) => (
                <SidebarMenuItem key={item.labelKey}>
                  <SidebarMenuButton
                    asChild
                    isActive={!item.soon && location.pathname === item.href}
                    tooltip={t(item.labelKey)}
                    className="h-11 text-[0.95rem] md:h-8 md:text-sm"
                    onClick={(e) => {
                      if (item.soon) {
                        e.preventDefault()
                        toast(t("common.comingSoon", { feature: t(item.labelKey) }))
                        return
                      }
                      setOpenMobile(false)
                    }}
                  >
                    <Link to={item.href}>
                      <item.icon />
                      <span>{t(item.labelKey)}</span>
                    </Link>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              ))}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>

        <SidebarGroup>
          <SidebarGroupLabel className="flex items-center gap-1.5">
            <Dumbbell className="size-3.5" /> {t("nav.workouts")}
          </SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {workoutItems.map((item) => (
                <SidebarMenuItem key={item.labelKey}>
                  <SidebarMenuButton
                    asChild
                    isActive={!item.soon && location.pathname === item.href}
                    tooltip={t(item.labelKey)}
                    className="h-11 text-[0.95rem] md:h-8 md:text-sm"
                    onClick={(e) => {
                      if (item.soon) {
                        e.preventDefault()
                        toast(t("common.comingSoon", { feature: t(item.labelKey) }))
                        return
                      }
                      setOpenMobile(false)
                    }}
                  >
                    <Link to={item.href}>
                      <item.icon />
                      <span>{t(item.labelKey)}</span>
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
        <div className="flex justify-center pb-1 group-data-[collapsible=icon]:hidden">
          <LanguageToggle />
        </div>
        <SidebarMenu>
          <SidebarMenuItem>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <SidebarMenuButton size="lg" tooltip={name}>
                  <Avatar className="size-6">
                    <AvatarFallback className="bg-[var(--accent-tint)] text-xs text-[var(--accent-ink)]">
                      {initials}
                    </AvatarFallback>
                  </Avatar>
                  <span className="truncate capitalize">{name}</span>
                  <ChevronsUpDown className="ms-auto size-4 text-muted-foreground" />
                </SidebarMenuButton>
              </DropdownMenuTrigger>
              <DropdownMenuContent side="top" align="start" className="w-(--radix-dropdown-menu-trigger-width) min-w-56">
                <DropdownMenuItem
                  onClick={() => {
                    navigate("/dashboard/profile")
                    setOpenMobile(false)
                  }}
                >
                  <UserRound /> {t("nav.profile")}
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => signOut()}>
                  <LogOut /> {t("nav.signOut")}
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
    </Sidebar>
  )
}
