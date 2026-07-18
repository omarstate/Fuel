import fuelMark from "@/assets/fuel-mark.png"

export function LogoMark({ className }: { className?: string }) {
  return <img src={fuelMark} alt="" className={className} aria-hidden="true" />
}
