import fuelMark from "@/assets/fuel-mark.png"

/**
 * Fuel mark for the editorial app. Renders the fixed brand image — it no
 * longer recolors per mode since a raster asset can't be retinted, but the
 * accent/spark props stay in the signature so call sites don't need to change.
 */
export function LogoMark({
  className,
  accent: _accent,
  spark: _spark,
}: {
  className?: string
  accent?: string
  spark?: string
}) {
  return <img src={fuelMark} alt="" className={className} aria-hidden="true" />
}
