import * as React from "react"
import { BrowserMultiFormatReader, type IScannerControls } from "@zxing/browser"

/** Turn a getUserMedia/scanner failure into a message we can show the user. */
function cameraErrorMessage(err: unknown): string {
  const name = (err as { name?: string })?.name
  if (name === "NotAllowedError" || name === "SecurityError") {
    return "Camera access was blocked. Allow it in your browser settings, or type the barcode below."
  }
  if (name === "NotFoundError" || name === "OverconstrainedError") {
    return "No camera available. Type the barcode below instead."
  }
  return "Couldn't start the camera. Type the barcode below instead."
}

/**
 * iOS Safari blocks `video.play()` when it isn't tied to a user gesture — and
 * always in Low Power Mode — rejecting with NotAllowedError/AbortError on the
 * play() call itself (distinct from a getUserMedia permission denial). When
 * that happens we surface a tap-to-start button; the tap is a gesture, which
 * iOS accepts.
 */
function isAutoplayBlock(err: unknown): boolean {
  const name = (err as { name?: string })?.name
  return name === "NotAllowedError" || name === "AbortError"
}

function stopStream(stream: MediaStream | null) {
  stream?.getTracks().forEach((track) => track.stop())
}

/**
 * Live barcode scanning via ZXing. Used instead of the native BarcodeDetector
 * API because that isn't implemented in Safari/iOS at all — ZXing decodes from
 * the camera stream in JS and works everywhere. Prefers the rear camera.
 *
 * We deliberately drive getUserMedia + playback ourselves rather than handing
 * constraints to ZXing's `decodeFromConstraints`. That path sets the video's
 * `muted` via setAttribute, which iOS Safari ignores, so autoplay is blocked,
 * play() rejects, and ZXing swallows the error — leaving a permanent black box
 * with no feedback. Here we set `muted` as a property (required for iOS
 * autoplay), await play() so failures are visible, and only then pass the
 * already-playing element to ZXing (which won't re-request the camera).
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
  // True when iOS blocked autoplay — the UI shows a "tap to start" button.
  const [needsTap, setNeedsTap] = React.useState(false)

  // Keep the latest callback without restarting the camera each render.
  const onDetectRef = React.useRef(onDetect)
  onDetectRef.current = onDetect

  const streamRef = React.useRef<MediaStream | null>(null)
  const readerRef = React.useRef<BrowserMultiFormatReader | null>(null)
  const controlsRef = React.useRef<IScannerControls | null>(null)
  const cancelledRef = React.useRef(false)

  // Play the (already-attached) video, then start decoding. Split out so the
  // tap-to-start button can re-run it from inside a real user gesture.
  const playAndDecode = React.useCallback(async () => {
    const video = videoRef.current
    const reader = readerRef.current
    if (!video || !reader) return
    try {
      await video.play()
      if (cancelledRef.current) return
      setNeedsTap(false)
      // Video is playing now, so ZXing's internal play() returns immediately
      // instead of hanging; it just runs the decode loop on our element.
      const controls = await reader.decodeFromVideoElement(video, (result) => {
        if (result && !cancelledRef.current) onDetectRef.current(result.getText())
      })
      if (cancelledRef.current) controls.stop()
      else controlsRef.current = controls
    } catch (err) {
      if (cancelledRef.current) return
      if (isAutoplayBlock(err)) setNeedsTap(true)
      else setError(cameraErrorMessage(err))
    }
  }, [])

  // Handler for the tap-to-start button (runs inside a user gesture).
  const startCamera = React.useCallback(() => {
    void playAndDecode()
  }, [playAndDecode])

  React.useEffect(() => {
    if (!active) return
    const video = videoRef.current
    if (!video) return

    cancelledRef.current = false
    readerRef.current = new BrowserMultiFormatReader()
    setError(null)
    setNeedsTap(false)

    void (async () => {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: { ideal: "environment" } },
          audio: false,
        })
        if (cancelledRef.current) {
          stopStream(stream)
          return
        }
        streamRef.current = stream
        // `muted` MUST be a property, not just an attribute, for iOS autoplay.
        video.muted = true
        video.setAttribute("playsinline", "true")
        video.srcObject = stream
        await playAndDecode()
      } catch (err) {
        if (cancelledRef.current) return
        setError(cameraErrorMessage(err))
      }
    })()

    return () => {
      cancelledRef.current = true
      controlsRef.current?.stop()
      controlsRef.current = null
      stopStream(streamRef.current)
      streamRef.current = null
      if (video) video.srcObject = null
      readerRef.current = null
    }
  }, [active, playAndDecode])

  return { videoRef, error, needsTap, startCamera }
}
