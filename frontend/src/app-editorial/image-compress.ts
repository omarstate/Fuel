// Downscale + re-encode a picked photo before upload. A 4MB phone photo becomes
// a few hundred KB, which keeps uploads fast on mobile networks and Gemini costs
// low — while staying large enough to read (the label reader rejects thin text
// at low resolution, so we don't shrink below ~1280px on the long edge).

export type CompressedImage = {
  /** Full data URL, for showing a preview thumbnail. */
  dataUrl: string
  /** Raw base64 (no data-URL prefix), for the API. */
  base64: string
  mimeType: "image/jpeg"
}

const MAX_EDGE = 1280
const QUALITY = 0.9

function fit(w: number, h: number): { width: number; height: number } {
  const longest = Math.max(w, h)
  if (longest <= MAX_EDGE) return { width: w, height: h }
  const scale = MAX_EDGE / longest
  return { width: Math.round(w * scale), height: Math.round(h * scale) }
}

// Prefer createImageBitmap with EXIF orientation applied (so portrait phone
// photos aren't logged sideways); fall back to an <img> for older browsers.
async function loadImage(
  file: File
): Promise<{ draw: CanvasImageSource; width: number; height: number; done: () => void }> {
  if (typeof createImageBitmap === "function") {
    try {
      const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" })
      return {
        draw: bitmap,
        width: bitmap.width,
        height: bitmap.height,
        done: () => bitmap.close(),
      }
    } catch {
      // fall through to the <img> path
    }
  }

  const url = URL.createObjectURL(file)
  try {
    const img = await new Promise<HTMLImageElement>((resolve, reject) => {
      const el = new Image()
      el.onload = () => resolve(el)
      el.onerror = () => reject(new Error("Couldn't read that image."))
      el.src = url
    })
    return {
      draw: img,
      width: img.naturalWidth,
      height: img.naturalHeight,
      done: () => URL.revokeObjectURL(url),
    }
  } catch (err) {
    URL.revokeObjectURL(url)
    throw err
  }
}

export async function compressImage(file: File): Promise<CompressedImage> {
  const { draw, width, height, done } = await loadImage(file)
  try {
    const size = fit(width, height)
    const canvas = document.createElement("canvas")
    canvas.width = size.width
    canvas.height = size.height
    const ctx = canvas.getContext("2d")
    if (!ctx) throw new Error("This browser can't process images.")
    ctx.drawImage(draw, 0, 0, size.width, size.height)
    const dataUrl = canvas.toDataURL("image/jpeg", QUALITY)
    const base64 = dataUrl.replace(/^data:[^;,]+;base64,/, "")
    return { dataUrl, base64, mimeType: "image/jpeg" }
  } finally {
    done()
  }
}
