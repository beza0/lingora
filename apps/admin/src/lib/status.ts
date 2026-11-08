// İçerik yayın akışı: Taslak → İncelendi → Yayımlandı. Silme yok; içerik arşivlenir.
export type ContentStatus = "draft" | "reviewed" | "published" | "archived";

export const STATUS_LABEL: Record<ContentStatus, string> = {
  draft: "Taslak",
  reviewed: "İncelendi",
  published: "Yayımlandı",
  archived: "Arşivlendi",
};

export const STATUS_STYLE: Record<ContentStatus, string> = {
  draft: "bg-warn-soft text-warn",
  reviewed: "bg-primary-soft text-primary-text",
  published: "bg-ok-soft text-ok",
  archived: "bg-surface2 text-muted",
};

export type StatusAction = { to: ContentStatus; label: string; primary?: boolean };

export function nextActions(status: ContentStatus): StatusAction[] {
  switch (status) {
    case "draft":
      return [{ to: "reviewed", label: "İncelendi olarak işaretle", primary: true }, { to: "archived", label: "Arşivle" }];
    case "reviewed":
      return [{ to: "published", label: "Yayımla", primary: true }, { to: "draft", label: "Taslağa geri al" }, { to: "archived", label: "Arşivle" }];
    case "published":
      return [{ to: "archived", label: "Yayından kaldır (arşivle)" }];
    case "archived":
      return [{ to: "draft", label: "Taslağa geri al" }];
  }
}

export function canPublish(status: ContentStatus): boolean {
  return status === "reviewed" || status === "published";
}
