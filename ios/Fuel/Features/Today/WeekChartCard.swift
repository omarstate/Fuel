import SwiftUI
import Charts

// The compact, quiet week chart on Today: Mon-first calorie bars with today
// highlighted, a dashed goal line, un-logged past days shown as baseline markers
// (distinct from a genuine zero), and a one-line direction-aware summary below.
struct WeekChartCard: View {
  let days: [WeekDay]
  let summary: WeekSummary
  let goal: Int

  // Locale-aware very-short weekday symbols, reordered Monday-first to match the
  // Mon-first data (Arabic yields ن ث ر خ ج س ح automatically).
  private var letters: [String] {
    let symbols = Calendar.current.veryShortWeekdaySymbols // index 0 = Sunday
    let monFirst = [1, 2, 3, 4, 5, 6, 0]
    return monFirst.map { symbols[$0] }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 3) {
        Text("This week").fuelEyebrow()
        Text("Calories vs goal")
          .font(.fuelHeading(.headline, weight: 600))
          .foregroundStyle(Color.fuelInk)
      }

      chart
        .frame(height: 120)
        .accessibilityLabel(Text("Calories vs goal"))

      if summary.hasData {
        Divider().overlay(Color.fuelInk.opacity(0.06))
        statsRow
        Text(summary.text)
          .font(.fuelBody(.caption, weight: 600))
          .foregroundStyle(summary.onTrack ? Color.fuelVoltInk : Color.fuelOver)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(
            (summary.onTrack ? Color.fuelOlive.opacity(0.15) : Color.fuelOver.opacity(0.12)),
            in: Capsule()
          )
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .fuelCard()
  }

  // "ON TARGET 4/6 days · DAILY AVG 2,014 · NET VS GOAL −1,407 kcal this week"
  private var statsRow: some View {
    HStack(alignment: .top, spacing: 12) {
      stat(label: "On target",
           value: Text("\(summary.daysOnTarget)/\(summary.trackedCount)"),
           caption: "days")
      stat(label: "Daily avg",
           value: Text("\(summary.dailyAverage)"),
           caption: "of \(goal) kcal")
      stat(label: "Net vs goal",
           value: netValueText,
           caption: "kcal this week")
    }
  }

  // Signed net with an explicit minus/plus, kept LTR so the sign never reorders.
  private var netValueText: Text {
    let magnitude = Text("\(abs(summary.net))")
    if summary.net < 0 { return Text("−\(magnitude)") }
    if summary.net > 0 { return Text("+\(magnitude)") }
    return magnitude
  }

  private func stat(label: LocalizedStringKey, value: Text, caption: LocalizedStringKey) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(label).fuelEyebrow(size: 9)
      value
        .font(.fuelMono(.title3, weight: 600))
        .foregroundStyle(Color.fuelInk)
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .environment(\.layoutDirection, .leftToRight)
      Text(caption)
        .font(.fuelMono(.caption2))
        .foregroundStyle(Color.fuelSubtle)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var chart: some View {
    Chart {
      RuleMark(y: .value("Goal", goal))
        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        .foregroundStyle(Color.fuelSubtle.opacity(0.55))

      ForEach(days) { day in
        if day.logged {
          BarMark(
            x: .value("Day", day.index),
            y: .value("kcal", day.calories),
            width: .fixed(16)
          )
          .foregroundStyle(day.isToday ? Color.fuelVolt : Color.fuelInk.opacity(0.22))
          .cornerRadius(4)
          .accessibilityLabel(Text(letters[day.index]))
          .accessibilityValue(Text("\(day.calories) kcal"))
        } else if !day.isFuture {
          PointMark(
            x: .value("Day", day.index),
            y: .value("kcal", 0)
          )
          .symbolSize(60)
          .foregroundStyle(Color.fuelSubtle.opacity(0.45))
        }
      }
    }
    .chartXScale(domain: -0.5...6.5)
    .chartYAxis(.hidden)
    .chartXAxis {
      AxisMarks(values: Array(0..<7)) { value in
        AxisValueLabel {
          if let i = value.as(Int.self), days.indices.contains(i) {
            Text(letters[i])
              .font(.fuelMono(.caption2, weight: days[i].isToday ? 700 : 400))
              .foregroundStyle(
                days[i].isToday
                  ? Color.fuelInk
                  : (days[i].isFuture ? Color.fuelSubtle.opacity(0.5) : Color.fuelSubtle)
              )
          }
        }
      }
    }
  }
}

#Preview {
  let days = WeekAggregation.buildWeek(perDayCalories: [
    DayBounds.dayKey(DayBounds.addDays(WeekAggregation.startOfWeek(Date()), 0)): 2100,
    DayBounds.dayKey(DayBounds.addDays(WeekAggregation.startOfWeek(Date()), 1)): 2600,
    DayBounds.dayKey(DayBounds.addDays(WeekAggregation.startOfWeek(Date()), 3)): 1800,
  ])
  return WeekChartCard(
    days: days,
    summary: WeekAggregation.summary(days: days, goal: 2200, direction: .cut),
    goal: 2200
  )
  .padding()
  .background(Color.fuelBackground)
}
