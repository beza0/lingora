import type { ButtonHTMLAttributes, ReactNode } from "react";
import { STATUS_LABEL, STATUS_STYLE, type ContentStatus } from "../lib/status";

export function StatusChip({ status }: { status: ContentStatus }) {
  return <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold ${STATUS_STYLE[status]}`}>{STATUS_LABEL[status]}</span>;
}

export function Button({ variant = "secondary", className = "", ...rest }: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "secondary" | "ghost" }) {
  const styles = {
    primary: "bg-primary text-white hover:opacity-90 disabled:bg-surface2 disabled:text-muted",
    secondary: "border border-line bg-surface text-primary-text hover:bg-surface2 disabled:text-muted",
    ghost: "text-primary-text hover:bg-surface2",
  }[variant];
  return <button type="button" className={`inline-flex min-h-10 items-center justify-center gap-2 rounded-xl px-4 text-sm font-semibold disabled:cursor-not-allowed ${styles} ${className}`} {...rest} />;
}

export function Card({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`rounded-2xl border border-line bg-surface p-5 ${className}`}>{children}</div>;
}

export function Banner({ tone = "info", children }: { tone?: "info" | "warn" | "error" | "ok"; children: ReactNode }) {
  const s = { info: "bg-surface2", warn: "bg-warn-soft", error: "bg-bad-soft text-bad", ok: "bg-ok-soft text-ok" }[tone];
  return <div role={tone === "error" ? "alert" : "status"} className={`rounded-xl px-4 py-3 text-sm ${s}`}>{children}</div>;
}

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="flex flex-col gap-1.5">
      <span className="text-sm font-semibold">{label}</span>
      {children}
    </label>
  );
}

export const inputClass = "min-h-11 w-full rounded-xl border-[1.5px] border-line bg-surface px-3.5 py-2 text-[15px] outline-none focus:border-primary";

export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: string; actions?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 className="text-[26px] font-bold leading-8">{title}</h1>
        {subtitle && <p className="text-[15px] text-muted">{subtitle}</p>}
      </div>
      {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
    </div>
  );
}

export function Loading() {
  return <p className="text-sm text-muted" aria-busy="true">Yükleniyor…</p>;
}

export function ErrorText({ error }: { error: unknown }) {
  return <Banner tone="error">{error instanceof Error ? error.message : String(error)}</Banner>;
}
