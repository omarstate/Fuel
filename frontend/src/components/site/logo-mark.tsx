export function LogoMark({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 32 32"
      fill="none"
      className={className}
      aria-hidden="true"
    >
      <rect width="32" height="32" rx="9" fill="#FF6B35" />
      <path
        d="M16.8 6.5c.3 3.1-1 5-2.9 6.9-2.2 2.2-3.4 4.2-3.1 7 .2 2 1.4 3.6 3.1 4.6-1-1.6-1-3 .1-4.6.4 1.4 1.1 2.2 2.3 2.9-.4-1.8.1-3 1.4-4.2 1.7-1.6 2.3-3.3 1.7-5.5 1.2.7 2 1.8 2.2 3.2.7-3.4-.5-7.4-4.8-10.3Z"
        fill="#14120F"
      />
      <circle cx="23.5" cy="9" r="2" fill="#D4FF3F" />
    </svg>
  )
}
