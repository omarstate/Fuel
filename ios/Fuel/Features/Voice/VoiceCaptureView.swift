import SwiftUI

// The capture half of both voice flows, as a mini modal: it opens already
// listening, shows a live waveform driven by the real microphone, one line of
// what it heard so far, and a single Confirm button. Nothing else — no language
// picker (the recorder detects it), no form fields, no second decision.
//
// The waveform is the whole point of the small sheet: it is the "you are being
// recorded" signal, and it is honest — the bars move with the actual buffer RMS,
// so silence looks like silence and the user knows to speak up.
//
// The typed path survives everything. When speech is denied, unavailable or
// dead, the wave is replaced by the notice plus a real editable field, and
// Confirm still works — that fallback is also the ONLY thing the simulator can
// show, since its speech assets are broken.
struct VoiceCaptureView: View {
  let recorder: SpeechRecorder
  /// `.fuelCitrus` for meals, `.fuelWorkout` for workouts — the fill.
  let accent: Color
  /// The matching ink for small text and glyphs; a saturated fill is unreadable
  /// at caption size on cream.
  let accentInk: Color
  /// An example utterance in the app's language, used as the placeholder.
  let example: String
  let isAnalyzing: Bool
  let canConfirm: Bool
  var onConfirm: () async -> Void

  @FocusState private var typing: Bool

  var body: some View {
    VStack(spacing: 18) {
      Text(statusEyebrow)
        .fuelEyebrow(color: recorder.isRecording ? accentInk : .fuelSubtle)
        .animation(.snappy, value: recorder.isRecording)

      if hasFallback {
        fallback
      } else {
        waveButton
      }

      transcriptLine

      Spacer(minLength: 0)

      confirmButton
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .padding(.horizontal, 20)
    .padding(.top, 14)
    .padding(.bottom, 18)
    .background(Color.fuelBackground)
    // The fallback field is multiline, so Return inserts a newline — this is the
    // only way off the keyboard in a sheet this small.
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { typing = false }
      }
    }
  }

  /// True when speech can't run at all and the user must type instead.
  private var hasFallback: Bool {
    switch recorder.state {
    case .denied, .unavailable, .failed: return true
    default: return false
    }
  }

  private var statusEyebrow: LocalizedStringKey {
    switch recorder.state {
    case .recording: return "Listening…"
    case .requestingPermission: return "Asking for permission…"
    case .denied, .unavailable: return "Type it instead"
    case .failed: return "Couldn't listen"
    case .idle, .stopped: return "Paused — tap the wave to resume"
    }
  }

  // MARK: - Waveform

  private var waveButton: some View {
    Button {
      if recorder.isRecording {
        recorder.stop()
      } else {
        Task { await recorder.start() }
      }
    } label: {
      VoiceWaveform(recorder: recorder, accent: accent)
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(recorder.state == .requestingPermission)
    .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Resume recording")
  }

  // MARK: - Transcript

  @ViewBuilder
  private var transcriptLine: some View {
    if hasFallback {
      // The fallback already owns an editable field; a second copy of the same
      // text underneath it would just be noise.
      EmptyView()
    } else if recorder.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      Text(example)
        .font(.fuelBody(.subheadline))
        .foregroundStyle(Color.fuelSubtle.opacity(0.6))
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    } else {
      Text(recorder.transcript)
        .font(.fuelBody(.subheadline))
        .foregroundStyle(Color.fuelSubtle)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: recorder.transcript)
    }
  }

  // MARK: - Fallback (denied / unavailable / failed)

  private var fallback: some View {
    // A local @Bindable turns the observable recorder into the binding the text
    // field needs, without making the caller hand one over.
    @Bindable var recorder = recorder
    return VStack(alignment: .leading, spacing: 8) {
      if let notice = permissionNotice {
        Text(notice)
          .font(.fuelBody(.footnote))
          .foregroundStyle(accentInk)
      }
      // iOS has already localized its own failure text, so it is shown verbatim
      // under our copy.
      if recorder.state == .failed, let detail = recorder.failureDetail {
        Text(detail)
          .font(.fuelBody(.caption2))
          .foregroundStyle(Color.fuelSubtle)
      }

      TextField(example, text: $recorder.transcript, axis: .vertical)
        .lineLimit(2...4)
        .focused($typing)
        .font(.fuelBody(.body))
        .foregroundStyle(Color.fuelInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
          RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
            .fill(Color.fuelSurface)
        )
        .overlay(
          RoundedRectangle(cornerRadius: FuelRadius.small, style: .continuous)
            .strokeBorder(Color.fuelInk.opacity(0.08))
        )
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var permissionNotice: LocalizedStringKey? {
    switch recorder.state {
    case .denied:
      return "Fuel can't hear you — microphone or speech access is off. Turn it on in Settings, or just type it below."
    case .unavailable:
      return "Speech recognition isn't available on this device. Type it below instead."
    case .failed:
      return "Speech recognition stopped before it heard anything. Type it below instead."
    default:
      return nil
    }
  }

  // MARK: - Confirm

  private var confirmButton: some View {
    AsyncButton(
      style: .glassProminent,
      tint: accent,
      action: { await onConfirm() }
    ) {
      Label("Confirm", systemImage: "checkmark")
        .font(.fuelBody(.subheadline, weight: 600))
        .frame(maxWidth: .infinity, minHeight: 26)
    }
    .controlSize(.large)
    .disabled(!canConfirm || isAnalyzing)
  }
}

// MARK: - Waveform

// A symmetric equalizer: the newest sample lands in the MIDDLE and older ones
// ride outward to both edges, so a spoken word blooms from the centre rather
// than scrolling past like a strip chart.
//
// Samples are pulled on a fixed 20 Hz tick rather than from `onChange` of the
// level: in a quiet room the normalized level pins at exactly 0 and would stop
// publishing changes, freezing the bars solid at the very moment the user is
// wondering whether the mic is even on. The tick also folds in a small random
// floor while recording, which is that "still listening" shimmer.
private struct VoiceWaveform: View {
  let recorder: SpeechRecorder
  let accent: Color

  /// Half the bars — the other half is this mirrored.
  private static let halfCount = 14
  private static let minHeight: CGFloat = 4
  private static let maxHeight: CGFloat = 76

  @State private var half: [Double] = Array(repeating: 0, count: halfCount)

  private var bars: [Double] { half.reversed() + half }

  var body: some View {
    HStack(spacing: 4) {
      ForEach(Array(bars.enumerated()), id: \.offset) { index, sample in
        Capsule(style: .continuous)
          .fill(accent)
          .frame(width: 4, height: height(sample, at: index))
      }
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .opacity(recorder.isRecording ? 1 : 0.4)
    .animation(.snappy(duration: 0.18), value: half)
    .animation(.snappy, value: recorder.isRecording)
    .accessibilityHidden(true)
    .task(id: recorder.isRecording) {
      guard recorder.isRecording else {
        // Settle flat when we're not listening, so a paused wave reads as paused.
        half = Array(repeating: 0, count: Self.halfCount)
        return
      }
      while !Task.isCancelled, recorder.isRecording {
        // A hair of noise under the real level: silence should shimmer, not
        // flatline, or the control looks broken exactly when it is working.
        let shimmer = Double.random(in: 0.02...0.10)
        half = [max(recorder.level, shimmer)] + half.dropLast()
        try? await Task.sleep(for: .milliseconds(50))
      }
    }
  }

  /// Bars taper toward the edges so the row reads as one wave instead of 28
  /// independent meters.
  private func height(_ sample: Double, at index: Int) -> CGFloat {
    let distance = abs(Double(index) - (Double(bars.count) - 1) / 2)
    let taper = 1 - 0.55 * (distance / ((Double(bars.count) - 1) / 2))
    let scaled = min(max(sample, 0), 1) * taper
    return Self.minHeight + (Self.maxHeight - Self.minHeight) * CGFloat(scaled)
  }
}

#Preview {
  VoiceCaptureView(
    recorder: SpeechRecorder(),
    accent: .fuelCitrus,
    accentInk: .fuelCitrusInk,
    example: VoiceLanguage.english.example(for: .meal),
    isAnalyzing: false,
    canConfirm: true,
    onConfirm: {}
  )
}
