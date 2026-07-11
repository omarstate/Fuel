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
  Settings,
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
import { LogoMark } from "@/components/site/logo-mark"
import { ModeToggle } from "@/components/site/mode-toggle"
import { useMode } from "@/components/site/mode-context"

const nutritionItems = [
  { href: "/app/nutrition", label: "Overview", icon: Home, soon: false },
  { href: "/app/nutrition", label: "Recipes", icon: Soup, soon: true },
  { href: "/app/nutrition", label: "Water", icon: GlassWater, soon: true },
]

const workoutItems = [
  { href: "/app/workouts", label: "Overview", icon: Home, soon: false },
  { href: "/app/workouts", label: "Exercises", icon: ListChecks, soon: true },
  { href: "/app/workouts", label: "Progress", icon: TrendingUp, soon: true },
]

export function AppSidebar() {
  const location = useLocation()
  const navigate = useNavigate()
  const { mode } = useMode()

  return (
    <Sidebar collapsible="icon">
      <SidebarHeader className="gap-4 px-2 pt-2">
        <Link to="/" className="flex items-center gap-2.5 px-1">
          <LogoMark className="size-7 shrink-0" />
          <span className="font-heading text-base font-semibold tracking-tight text-sidebar-foreground group-data-[collapsible=icon]:hidden">
            Fuel
          </span>
        </Link>
        <div className="group-data-[collapsible=icon]:hidden">
          <ModeToggle
            className="w-full"
            value={mode}
            onValueChange={(next) => navigate(`/app/${next}`)}
          />
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
                    isActive={
                      !item.soon && location.pathname === item.href
                    }
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
                    isActive={
                      !item.soon && location.pathname === item.href
                    }
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
            <SidebarMenuButton
              size="lg"
              onClick={() => toast("Account settings are coming soon.")}
              tooltip="Settings"
            >
              <Avatar className="size-6">
                <AvatarFallback className="bg-citrus/20 text-xs text-citrus">
                  OM
                </AvatarFallback>
              </Avatar>
              <span>Omar</span>
              <Settings className="ml-auto size-4 text-smoke" />
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
    </Sidebar>
  )
}
