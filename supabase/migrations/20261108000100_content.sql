-- Lingora · içerik tabloları
-- Öğrenme hedefi alandan bağımsızdır (anlam veya kalıp); alanlar hedeflere paketler üzerinden bağlanır.

create extension if not exists pgcrypto;

create type public.content_status as enum ('draft', 'reviewed', 'published', 'archived');
create type public.target_kind as enum ('sense', 'pattern');
create type public.exercise_type as enum (
  'meaning_choice', 'cloze_choice', 'matching', 'synonym_choice', 'listen_choice',
  'recall_typing', 'dialogue_choice', 'tr_to_en', 'short_writing'
);
create type public.skill as enum ('vocab', 'reading', 'listening', 'writing');

-- Uygulama ayarları (ör. show_drafts, content_version)
create table public.app_config (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

create table public.domains (
  id text primary key check (id in ('general', 'software', 'engineering', 'yds')),
  name_tr text not null,
  description_tr text not null,
  color_key text not null,
  sort int not null default 0,
  status public.content_status not null default 'draft',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.packs (
  id uuid primary key,
  domain_id text not null references public.domains(id),
  slug text not null unique,
  title_tr text not null,
  description_tr text not null,
  sort int not null default 0,
  status public.content_status not null default 'draft',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.lexemes (
  id uuid primary key,
  lemma text not null,
  pos text not null,
  is_phrase boolean not null default false,
  status public.content_status not null default 'draft',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (lemma, pos)
);

create table public.senses (
  id uuid primary key,
  lexeme_id uuid not null references public.lexemes(id),
  meaning_tr text not null,
  definition_en text,
  register text,
  notes_tr text,
  status public.content_status not null default 'draft',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.sense_usages (
  id uuid primary key,
  sense_id uuid not null references public.senses(id),
  domain_id text not null references public.domains(id),
  example_en text not null,
  example_tr text not null,
  collocations text[] not null default '{}',
  family jsonb not null default '[]',
  synonyms text[] not null default '{}',
  antonyms text[] not null default '{}',
  confusables jsonb not null default '[]',
  other_meanings_tr text,
  tone_tags text[] not null default '{}',
  status public.content_status not null default 'draft',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (sense_id, domain_id)
);

create table public.grammar_notes (
  id uuid primary key,
  slug text not null unique,
  title_tr text not null,
  short_tr text not null,
  long_tr text not null,
  examples jsonb not null default '[]',
  status public.content_status not null default 'draft',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.patterns (
  id uuid primary key,
  template_en text not null,
  slot_key text not null,
  example_en text not null,
  example_tr text not null,
  template_tr text,
  chunks jsonb not null default '[]',
  grammar_note_id uuid references public.grammar_notes(id),
  context_tags text[] not null default '{}',
  tone_tags text[] not null default '{}',
  status public.content_status not null default 'draft',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.pattern_slots (
  id uuid primary key,
  pattern_id uuid not null references public.patterns(id) on delete cascade,
  text_en text not null,
  text_tr text not null,
  sentence_tr text,
  sort int not null default 0
);

-- Kalıcı öğrenme hedefi. Kimlik asla yeniden kullanılmaz.
create table public.learning_targets (
  id uuid primary key,
  slug text not null unique,
  kind public.target_kind not null,
  sense_id uuid references public.senses(id),
  pattern_id uuid references public.patterns(id),
  difficulty smallint not null check (difficulty between 1 and 5),
  status public.content_status not null default 'draft',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((kind = 'sense' and sense_id is not null and pattern_id is null)
      or (kind = 'pattern' and pattern_id is not null and sense_id is null))
);

create table public.pack_targets (
  pack_id uuid not null references public.packs(id) on delete cascade,
  target_id uuid not null references public.learning_targets(id),
  sort int not null default 0,
  is_core boolean not null default true,
  primary key (pack_id, target_id)
);

create table public.exercises (
  id uuid primary key,
  target_id uuid not null references public.learning_targets(id),
  type public.exercise_type not null,
  skill public.skill not null,
  prompt jsonb not null,
  answer jsonb not null,
  accepted_answers text[] not null default '{}',
  distractor_notes jsonb not null default '{}',
  explanation_tr text not null,
  group_target_ids uuid[] not null default '{}',
  difficulty smallint not null check (difficulty between 1 and 5),
  status public.content_status not null default 'draft',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.scenarios (
  id uuid primary key,
  pack_id uuid not null references public.packs(id),
  title_tr text not null,
  situation_tr text not null,
  turns jsonb not null,
  target_ids uuid[] not null default '{}',
  mode text not null default 'choice' check (mode in ('choice', 'free')),
  difficulty smallint not null check (difficulty between 1 and 5),
  status public.content_status not null default 'draft',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.readings (
  id uuid primary key,
  pack_id uuid not null references public.packs(id),
  title text not null,
  kind text not null,
  sentences jsonb not null,
  glossary jsonb not null default '[]',
  questions jsonb not null,
  difficulty smallint not null check (difficulty between 1 and 5),
  status public.content_status not null default 'draft',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.writing_tasks (
  id uuid primary key,
  pack_id uuid not null references public.packs(id),
  prompt_tr text not null,
  rubric jsonb not null,
  sample_answers text[] not null,
  difficulty smallint not null check (difficulty between 1 and 5),
  status public.content_status not null default 'draft',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.pack_grammar_notes (
  pack_id uuid not null references public.packs(id) on delete cascade,
  grammar_note_id uuid not null references public.grammar_notes(id),
  sort int not null default 0,
  primary key (pack_id, grammar_note_id)
);

-- Cümle Rehberi durum ağacı
create table public.situations (
  id uuid primary key,
  domain_id text not null references public.domains(id),
  parent_id uuid references public.situations(id),
  name_tr text not null,
  sort int not null default 0,
  status public.content_status not null default 'draft',
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.situation_items (
  situation_id uuid not null references public.situations(id) on delete cascade,
  target_id uuid not null references public.learning_targets(id),
  sort int not null default 0,
  primary key (situation_id, target_id)
);

-- Değişiklik geçmişi (tetikleyici yazar)
create table public.content_revisions (
  id bigint generated always as identity primary key,
  entity_type text not null,
  entity_id text not null,
  version int not null,
  snapshot jsonb not null,
  status_from public.content_status,
  status_to public.content_status,
  editor_id uuid,
  note text,
  created_at timestamptz not null default now()
);
create index content_revisions_entity_idx on public.content_revisions (entity_type, entity_id, created_at desc);

create index packs_domain_idx on public.packs (domain_id, sort);
create index senses_lexeme_idx on public.senses (lexeme_id);
create index exercises_target_idx on public.exercises (target_id);
create index pack_targets_target_idx on public.pack_targets (target_id);
create index learning_targets_status_idx on public.learning_targets (status);
