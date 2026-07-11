import { isAdmin } from "../utils/is-admin.js"

export const getMe = async (req, res) => {
  res.json({
    data: {
      id: req.user.id,
      email: req.user.email,
      isAdmin: isAdmin(req.user),
    },
  })
}
