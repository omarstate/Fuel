import SwiftUI

// The floating rest bar pinned to the bottom of the active session. This is the
// one genuinely FLOATING element of the workouts flow, so per DESIGN.md it is
// the one place here that gets real Liquid Glass — the cards above it stay
// opaque cream. The three states live in a single GlassEffectContainer and share
// a `glassEffectID`, so idle → running → done morphs rather than cuts.
//
// Port of `RestTimerBar` in workouts/session/rest-timer.tsx: preset chips when
// idle, a countdown with ±15s / skip while running, and a brief "GO" flash at
// zero. The countdown is rendered inside a TimelineView and read from
// `timer.remaining(at:)`, so what's on screen is always derived from the end
// timestamp rather than from anything this view accumulated.
struct RestTimerBar: View {
  let timer: RestTimer

  @Namespace private var glass

  var body: some View {
    GlassEffectContainer(spacing: 14) {
      switch timer.phase {
      case .idle: idleBar
      case .running: runningBar
      case .done: doneBar
      }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 10)
    .animation(.snappy, value: timer.phase)
    .sensoryFeedback(.success, trigger: timer.finishTrigger)
  }

  // MARK: - Idle

  private var idleBar: some View {
    HStack(spacing: 4) {
      Text("Rest")
        .fuelEyebrow(size: 12, color: .white.opacity(0.75))
        .fixedSize()

      Spacer(minLength: 8)

      stepButton(-RestTimer.durationStep, systemImage: "minus", label: "Shorten rest by 30 seconds")

      Text(DurationFormat.rest(timer.duration))
        .font(.fuelMono(22, weight: 700, relativeTo: .title2))
        .foregroundStyle(.white)
        .contentTransition(.numericText())
        .lineLimit(1)
        .fixedSize()
        .frame(minWidth: 72)
        .environment(\.layoutDirection, .leftToRight)

      stepButton(RestTimer.durationStep, systemImage: "plus", label: "Extend rest by 30 seconds")

      Spacer(minLength: 8)

      Button {
        timer.soundOn.toggle()
      } label: {
        Image(systemName: timer.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.white.opacity(0.8))
          .frame(width: 40, height: 48)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(timer.soundOn ? "Mute end-of-rest sound" : "Unmute end-of-rest sound")

      Button {
        timer.start()
      } label: {
        Image(systemName: "play.fill")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(Color.fuelWorkoutInk)
          .frame(width: 40, height: 40)
          .background(Circle().fill(.white))
          .frame(width: 48, height: 48)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Start rest timer")
    }
    .padding(.leading, 18)
    .padding(.trailing, 6)
    .padding(.vertical, 6)
    .glassEffect(.regular.tint(.fuelWorkout).interactive(), in: .capsule)
    .glassEffectID("rest", in: glass)
  }

  private func stepButton(_ delta: Int, systemImage: String, label: LocalizedStringKey) -> some View {
    let atBound = delta < 0
      ? timer.duration <= RestTimer.durationRange.lowerBound
      : timer.duration >= RestTimer.durationRange.upperBound
    return Button {
      withAnimation(.snappy) { timer.bumpDuration(by: delta) }
    } label: {
      Image(systemName: systemImage)
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(.white.opacity(atBound ? 0.35 : 0.9))
        .frame(width: 40, height: 40)
        .background(Circle().fill(.white.opacity(0.14)).padding(3))
        .frame(height: 48)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(atBound)
    .accessibilityLabel(label)
  }

  // MARK: - Running

  private var runningBar: some View {
    TimelineView(.periodic(from: .now, by: 0.5)) { context in
      let seconds = timer.remaining(at: context.date)
      let ratio = timer.progress(at: context.date)

      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 1) {
            Text("Resting")
              .fuelEyebrow(size: 12, color: .white.opacity(0.75))
            Text(DurationFormat.rest(seconds))
              .font(.fuelMono(32, weight: 600, relativeTo: .largeTitle))
              .foregroundStyle(.white)
              .contentTransition(.numericText(countsDown: true))
              .environment(\.layoutDirection, .leftToRight)
          }

          Spacer(minLength: 0)

          adjustButton(-15, systemImage: "minus", label: "Shorten rest by 15 seconds")
          adjustButton(15, systemImage: "plus", label: "Extend rest by 15 seconds")

          Button {
            withAnimation(.snappy) { timer.skip() }
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(.white)
              .frame(width: 44, height: 44)
              .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Skip rest")
        }

        progressLine(ratio: ratio)

        Text(quote(at: seconds))
          .fuelEyebrow(size: 11, color: .white.opacity(0.75))
          .frame(maxWidth: .infinity, alignment: .center)
          .transition(.opacity)
          .id(quoteIndex(at: seconds))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .glassEffect(.regular.tint(.fuelWorkout).interactive(), in: .rect(cornerRadius: FuelRadius.card))
      .glassEffectID("rest", in: glass)
      .animation(.snappy, value: quoteIndex(at: seconds))
    }
  }

  private func adjustButton(_ delta: Int, systemImage: String, label: LocalizedStringKey) -> some View {
    Button {
      timer.adjust(by: delta)
    } label: {
      Image(systemName: systemImage)
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(.white.opacity(0.85))
        .frame(width: 44, height: 44)
        .background(Circle().fill(.white.opacity(0.14)).padding(4))
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  private func progressLine(ratio: Double) -> some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.22))
        Capsule()
          .fill(.white)
          .frame(width: max(0, geo.size.width * ratio))
      }
    }
    .frame(height: 3)
    .accessibilityHidden(true)
  }

  // MARK: - Done

  private var doneBar: some View {
    Button {
      withAnimation(.snappy) { timer.skip() }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "bolt.fill")
          .font(.system(size: 17, weight: .bold))
        Text("Rest over — GO 💥")
          .font(.fuelHeading(.headline))
      }
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 18)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .glassEffect(.regular.tint(.fuelWorkout).interactive(), in: .rect(cornerRadius: FuelRadius.card))
    .glassEffectID("rest", in: glass)
  }

  // MARK: - Quotes

  // Short lines rotated under the countdown, straight from the web's QUOTES.
  // They advance every ~10 seconds, offset by the rest number so two rests in a
  // row never open on the same line.
  private static let quotes: [LocalizedStringKey] = [
    "Rest hard. Lift harder.",
    "Muscles grow between the sets.",
    "Breathe. The next set is yours.",
    "Shake it out. Stay loose.",
    "You vs. you — you're winning.",
    "Strong is built one set at a time.",
    "Water break. You've earned it.",
    "Every rep counts. So does every breath.",
    "Nobody's watching. Do it for you.",
    "One quality set beats three sloppy ones.",
    "Show up. Log it. Level up.",
    "Discipline shows up even when motivation doesn't.",
  ]

  private func quoteIndex(at remaining: Int) -> Int {
    let elapsed = max(0, timer.total - remaining)
    let raw = timer.restCount * 3 + elapsed / 10
    return raw % Self.quotes.count
  }

  private func quote(at remaining: Int) -> LocalizedStringKey {
    Self.quotes[quoteIndex(at: remaining)]
  }
}

#Preview("Idle") {
  VStack {
    Spacer()
    RestTimerBar(timer: RestTimer())
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.fuelBackground)
}

#Preview("Running") {
  let timer = RestTimer()
  return VStack {
    Spacer()
    RestTimerBar(timer: timer)
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.fuelBackground)
  .onAppear { timer.start(seconds: 90) }
}
