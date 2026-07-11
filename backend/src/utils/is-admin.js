import { env } from "../config/env.js"

// True when the authenticated user's email is on the ADMIN_EMAILS allowlist
// (src/config/env.js). Admins can edit/delete any catalog meal, not just
// ones they created.
export const isAdmin = (user) => {
  const email = user?.email?.toLowerCase()
  return Boolean(email) && env.adminEmails.includes(email)
}
