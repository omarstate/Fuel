// In-memory waitlist store — kept simple on purpose, matches the original
// prototype behavior. Not persisted; resets on restart.
const waitlist = []

export const joinWaitlist = (req, res) => {
  const { email } = req.body ?? {}

  if (typeof email !== "string" || !/^\S+@\S+\.\S+$/.test(email)) {
    return res.status(400).json({ error: "Enter a valid email address." })
  }

  if (!waitlist.includes(email)) {
    waitlist.push(email)
  }

  res.status(201).json({ ok: true, position: waitlist.indexOf(email) + 1 })
}

export const getWaitlistCount = (_req, res) => {
  res.json({ count: waitlist.length })
}
