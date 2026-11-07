-- Lingora · kullanıcı tabloları
-- Bütün tablolar auth.users'a bağlıdır; hesap silinince satırlar da silinir.

create type public.session_status as enum ('in_progress', 'completed', 'abandoned');
create type public.answer_outcome as enum ('correct', 'correct_with_hint', 'minor_spelling', 'incorrect');

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  weekly_goal smallint check (weekly_goal is null or weekly_goal between 1 and 21),
  streak_enabled boolean not null default false,
  reminder_time time,
  settings jsonb not null default '{}',
  updated_at timestamptz not null default now()
);

create table public.user_domains (
  user_id uuid not null references auth.users(id) on delete cascade,
  domain_id text not null references public.domains(id),
  sort int not null default 0,
  active boolean not null default true,
  level_estimate smallint not null default 2 check (level_estimate between 1 and 5),
  updated_at timestamptz not null default now(),
  primary key (user_id, domain_id)
);

create table public.study_sessions (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  domain_id text not null references public.domains(id),
  status public.session_status not null default 'in_progress',
  plan jsonb not null,
  cursor int not null default 0,
  started_at timestamptz not null,
  updated_at timestamptz not null
);
create index study_sessions_user_idx on public.study_sessions (user_id, domain_id, status);

-- Değişmez cevap olayları. Tekil istemci UUID'si, tekrar gönderimde çift kaydı önler.
create table public.review_events (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid not null references public.learning_targets(id),
  exercise_id uuid references public.exercises(id),
  session_id uuid,
  skill public.skill not null,
  outcome public.answer_outcome not null,
  rating smallint not null check (rating between 1 and 4),
  hints_used smallint not null default 0 check (hints_used between 0 and 2),
  scheduled boolean not null default true,
  response_ms int,
  answered_at timestamptz not null,
  received_at timestamptz not null default now(),
  device_id text
);
create index review_events_user_target_idx on public.review_events (user_id, target_id, answered_at);

-- Olaylardan türetilen kart durumu (yeniden hesaplanabilir)
create table public.card_states (
  user_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid not null references public.learning_targets(id),
  stability double precision not null,
  difficulty double precision not null,
  due_at timestamptz not null,
  reps int not null default 0,
  lapses int not null default 0,
  state smallint not null check (state between 0 and 3),
  last_review_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, target_id)
);
create index card_states_due_idx on public.card_states (user_id, due_at);

create table public.skill_evidence (
  user_id uuid not null references auth.users(id) on delete cascade,
  domain_id text not null references public.domains(id),
  skill public.skill not null,
  attempts int not null default 0,
  correct int not null default 0,
  unaided_correct int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, domain_id, skill)
);

create table public.custom_items (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  text_en text not null check (char_length(text_en) between 1 and 300),
  meaning_tr text,
  note text,
  domain_id text references public.domains(id),
  source text not null check (source in ('manual', 'extracted', 'ai')),
  deleted_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.saved_items (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid references public.learning_targets(id),
  custom_item_id uuid references public.custom_items(id) on delete cascade,
  in_review boolean not null default false,
  deleted_at timestamptz,
  updated_at timestamptz not null default now(),
  check ((target_id is null) <> (custom_item_id is null))
);
create unique index saved_items_target_uq on public.saved_items (user_id, target_id) where target_id is not null;
create unique index saved_items_custom_uq on public.saved_items (user_id, custom_item_id) where custom_item_id is not null;

create table public.lists (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  domain_id text references public.domains(id),
  deleted_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.list_items (
  list_id uuid not null references public.lists(id) on delete cascade,
  saved_item_id uuid not null references public.saved_items(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (list_id, saved_item_id)
);

create table public.assessments (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  domain_id text not null references public.domains(id),
  steps jsonb not null,
  result_level smallint check (result_level between 1 and 5),
  chosen_level smallint check (chosen_level between 1 and 5),
  created_at timestamptz not null default now()
);

create table public.chat_threads (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Yeni sohbet',
  domain_id text references public.domains(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  context_ref jsonb,
  model text,
  created_at timestamptz not null default now()
);
create index chat_messages_thread_idx on public.chat_messages (thread_id, created_at);

create table public.content_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  entity_type text not null,
  entity_id uuid not null,
  reason text not null check (reason in ('wrong_answer', 'two_correct', 'translation', 'audio', 'typo', 'other')),
  text text check (char_length(text) <= 1000),
  status text not null default 'open' check (status in ('open', 'resolved', 'rejected')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.daily_activity (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  sessions int not null default 0,
  targets int not null default 0,
  primary key (user_id, day)
);

create table public.user_badges (
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_key text not null,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_key)
);

-- Yalnız sunucu (service role) erişir
create table public.ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  kind text not null check (kind in ('chat', 'eval')),
  requests int not null default 0,
  input_tokens int not null default 0,
  output_tokens int not null default 0,
  primary key (user_id, day, kind)
);

create table public.ai_ip_usage (
  ip_hash text not null,
  day date not null,
  requests int not null default 0,
  primary key (ip_hash, day)
);

create table public.ai_rate (
  user_id uuid not null,
  minute timestamptz not null,
  requests int not null default 0,
  primary key (user_id, minute)
);

create table public.merge_tokens (
  token_hash text primary key,
  anon_user_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
