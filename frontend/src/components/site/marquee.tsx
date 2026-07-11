const lines = [
  "Logged lunch before the fork left the plate",
  "PR on bench press, week 6",
  "Streak: 41 days and counting",
  "Rest timer started automatically",
  "Macros balanced without a spreadsheet",
  "Leg day logged from the gym floor",
]

export function Marquee() {
  const items = [...lines, ...lines]

  return (
    <div className="overflow-hidden border-b border-bone/10 bg-char-2/60 py-5">
      <div className="flex w-max animate-marquee gap-10 hover:[animation-play-state:paused]">
        {items.map((line, i) => (
          <span
            key={i}
            className="flex items-center gap-3 whitespace-nowrap text-sm text-smoke"
          >
            <span className="size-1.5 rounded-full bg-citrus" />
            {line}
          </span>
        ))}
      </div>
    </div>
  )
}
