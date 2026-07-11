import * as React from "react"
import { motion } from "framer-motion"
import { toast } from "sonner"
import { ArrowRight, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Field, FieldGroup } from "@/components/ui/field"
import { Input } from "@/components/ui/input"

const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:4000"

export function Cta() {
  const [email, setEmail] = React.useState("")
  const [status, setStatus] = React.useState<"idle" | "loading">("idle")

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!email) return
    setStatus("loading")
    try {
      const res = await fetch(`${API_URL}/api/waitlist`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      })
      if (!res.ok) throw new Error("Request failed")
      toast.success("You're on the list — check your inbox soon.")
      setEmail("")
    } catch {
      toast.error("Couldn't reach the server. Try again in a moment.")
    } finally {
      setStatus("idle")
    }
  }

  return (
    <section id="join" className="relative overflow-hidden py-28">
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-citrus/10 via-transparent to-volt/5" />
      <div className="relative mx-auto max-w-2xl px-6 text-center">
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-80px" }}
          transition={{ duration: 0.5 }}
        >
          <h2 className="font-heading text-4xl font-semibold tracking-tight text-bone sm:text-5xl">
            Start your streak today.
          </h2>
          <p className="mt-4 text-lg text-smoke">
            Free to log your first meal and your first set. No spreadsheet
            required.
          </p>

          <form
            onSubmit={handleSubmit}
            className="mx-auto mt-8 max-w-md"
          >
            <FieldGroup className="flex-row gap-2">
              <Field className="flex-1">
                <Input
                  type="email"
                  required
                  placeholder="you@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  aria-label="Email address"
                />
              </Field>
              <Button type="submit" size="lg" disabled={status === "loading"}>
                {status === "loading" ? (
                  <Loader2 className="animate-spin" data-icon="inline-start" />
                ) : (
                  <ArrowRight data-icon="inline-end" />
                )}
                Get started
              </Button>
            </FieldGroup>
          </form>
        </motion.div>
      </div>
    </section>
  )
}
