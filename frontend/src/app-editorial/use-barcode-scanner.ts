import * as React from "react"
import { BrowserMultiFormatReader, type IScannerControls } from "@zxing/browser"

/** Turn a getUserMedia/scanner failure into a message we can show the user. */
function cameraErrorMessage(err: unknown): string {
  const name = (err as { name?: string })?.name
  if (name === "NotAllowedError" || name === "SecurityError") {
    return "Camera access was blocked. Allow it in your browser, or type the barcode below."
  }
  if (name === "NotFoundError" || name === "OverconstrainedError") {
    return "No camera available. Type the barcode below instead."
  }
  return "Couldn't start the camera. Type the barcode below instead."
}

/**
 * Live barcode scanning via ZXing. Used instead of the native BarcodeDetector
 * API because that isn't implemented in Safari/iOS at all — ZXing decodes from
 * the camera stream in JS and works everywhere. Prefers the rear camera.
 *
 * `onDetect` fires with the decoded string; the caller is expected to flip
 * `active` to false (e.g. by advancing the step) to stop the camera.
 */
export function useBarcodeScanner({
  active,
  onDetect,
}: {
  active: boolean
  onDetect: (code: string) => void
}) {
  const videoRef = React.useRef<HTMLVideoElement>(null)
  const [error, setError] = React.useState<string | null>(null)

  // Keep the latest callback without restarting the camera each render.
  const onDetectRef = React.useRef(onDetect)
  onDetectRef.current = onDetect

  React.useEffect(() => {
    if (!active) return
    const video = videoRef.current
    if (!video) return

    let cancelled = false
    let controls: IScannerControls | undefined
    const reader = new BrowserMultiFormatReader()
    setError(null)

    reader
      .decodeFromConstraints(
        { video: { facingMode: { ideal: "environment" } } },
        video,
        (result) => {
          if (result && !cancelled) onDetectRef.current(result.getText())
        }
      )
      .then((c) => {
        if (cancelled) c.stop()
        else controls = c
      })
      .catch((err) => {
        if (!cancelled) setError(cameraErrorMessage(err))
      })

    return () => {
      cancelled = true
      controls?.stop()
    }
  }, [active])

  return { videoRef, error }
}
