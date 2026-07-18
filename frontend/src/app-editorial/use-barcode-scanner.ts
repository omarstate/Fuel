import * as React from "react"
import { BrowserMultiFormatReader, type IScannerControls } from "@zxing/browser"

/** Turn a getUserMedia/scanner failure into a message we can show the user. */
function cameraErrorMessage(err: unknown): string {
  const name = (err as { name?: string })?.name
  if (name === "NotAllowedError" || name === "SecurityError") {
    return "Camera access was blocked. Allow it in Safari's settings, or type the barcode below."
  }
  if (name === "NotFoundError" || name === "OverconstrainedError") {
    return "No camera available. Type the barcode below instead."
  }
  if (name === "TimeoutError") {
    return "The camera didn't start. Close any other app or tab using it, then try again."
  }
  return "Couldn't start the camera. Type the barcode below instead."
}

function stopStream(stream: MediaStream | null) {
  stream?.getTracks().forEach((track) => track.stop())
}

/** Reject if a promise hasn't settled in `ms` — iOS can leave getUserMedia or
 * play() pending forever when the camera is held elsewhere, which otherwise
 * shows as a permanent black box with no error. */
function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return new Promise((resolve, reject) => {
    const id = setTimeout(() => {
      const err = new Error("Camera timed out")
      err.name = "TimeoutError"
      reject(err)
    }, ms)
    promise.then(
      (v) => {
        clearTimeout(id)
        resolve(v)
      },
      (e) => {
        clearTimeout(id)
        reject(e)
      }
    )
  })
}

export type ScannerPhase = "idle" | "starting" | "running" | "error"

/**
 * Live barcode scanning via ZXing. Used instead of the native BarcodeDetector
 * API because that isn't implemented in Safari/iOS at all — ZXing decodes from
 * the camera stream in JS and works everywhere. Prefers the rear camera.
 *
 * The camera is **gesture-first**: nothing starts until `startCamera()` is
 * called from a real tap. This is deliberate — iOS Safari blocks (and can hang
 * indefinitely on) a `video.play()` that isn't inside a user gesture, which is
 * exactly the silent black-screen failure this avoids. We also drive
 * getUserMedia + playback ourselves rather than via ZXing's
 * `decodeFromConstraints`, because that path sets `muted` with setAttribute,
 * which iOS ignores; we set it as a property (required for iOS) and only hand
 * the already-playing element to ZXing.
 *
 * `onDetect` fires with the decoded string; the caller flips `active` to false
 * (e.g. by advancing the step) to tear the camera down.
 */
export function useBarcodeScanner({
  active,
  onDetect,
}: {
  active: boolean
  onDetect: (code: string) => void
}) {
  const videoRef = React.useRef<HTMLVideoElement>(null)
  const [phase, setPhase] = React.useState<ScannerPhase>("idle")
  const [error, setError] = React.useState<string | null>(null)

  // Keep the latest callback without restarting the camera each render.
  const onDetectRef = React.useRef(onDetect)
  onDetectRef.current = onDetect

  const streamRef = React.useRef<MediaStream | null>(null)
  const readerRef = React.useRef<BrowserMultiFormatReader | null>(null)
  const controlsRef = React.useRef<IScannerControls | null>(null)
  const cancelledRef = React.useRef(false)
  const busyRef = React.useRef(false)

  const teardown = React.useCallback(() => {
    controlsRef.current?.stop()
    controlsRef.current = null
    stopStream(streamRef.current)
    streamRef.current = null
    const video = videoRef.current
    if (video) video.srcObject = null
    busyRef.current = false
  }, [])

  // Acquire + play + decode. MUST be called from a user gesture on iOS.
  const startCamera = React.useCallback(async () => {
    const video = videoRef.current
    if (!video || busyRef.current) return
    busyRef.current = true
    cancelledRef.current = false
    setError(null)
    setPhase("starting")

    if (!readerRef.current) readerRef.current = new BrowserMultiFormatReader()

    try {
      const stream = await withTimeout(
        navigator.mediaDevices.getUserMedia({
          video: { facingMode: { ideal: "environment" } },
          audio: false,
        }),
        12000
      )
      if (cancelledRef.current) {
        stopStream(stream)
        return
      }
      streamRef.current = stream
      // `muted` MUST be a property, not just an attribute, for iOS autoplay.
      video.muted = true
      video.setAttribute("playsinline", "true")
      video.srcObject = stream

      // Inside a gesture this resolves quickly; the watchdog catches the rare
      // iOS case where it never settles.
      await withTimeout(video.play(), 8000)
      if (cancelledRef.current) return

      const reader = readerRef.current
      if (!reader) return
      // Video is already playing, so ZXing's internal play() returns at once
      // instead of hanging; it just runs the decode loop on our element.
      const controls = await reader.decodeFromVideoElement(video, (result) => {
        if (result && !cancelledRef.current) onDetectRef.current(result.getText())
      })
      if (cancelledRef.current) {
        controls.stop()
        return
      }
      controlsRef.current = controls
      setPhase("running")
    } catch (err) {
      if (cancelledRef.current) return
      setError(cameraErrorMessage(err))
      setPhase("error")
      teardown()
    }
  }, [teardown])

  // Tear the camera down whenever we go inactive (step change / dialog close).
  React.useEffect(() => {
    if (active) return
    cancelledRef.current = true
    teardown()
    readerRef.current = null
    setPhase("idle")
    setError(null)
  }, [active, teardown])

  // Safety net: stop the stream if the component unmounts mid-scan.
  React.useEffect(() => {
    return () => {
      cancelledRef.current = true
      teardown()
      readerRef.current = null
    }
  }, [teardown])

  return { videoRef, phase, error, startCamera }
}
