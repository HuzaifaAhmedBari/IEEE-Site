-- ─────────────────────────────────────────────────────────────
-- IEEE Xtreme Qualifier – Supabase Schema
-- Run in: Supabase Dashboard → SQL Editor
-- Project: ieee-xtreme-qualifier (brudvbdbximxzgvdspkv)
-- ─────────────────────────────────────────────────────────────

-- 1. Main registrations table (ONE ROW PER TEAM, all details flat)
create table if not exists public.registrations (
  id              uuid        primary key default gen_random_uuid(),
  team_name       text        not null,
  vjudge_id       text        not null,
  -- Participant 1
  p1_name         text        not null,
  p1_email        text        not null,
  p1_phone        text        not null,
  -- Participant 2
  p2_name         text        not null,
  p2_email        text        not null,
  p2_phone        text        not null,
  -- Participant 3
  p3_name         text        not null,
  p3_email        text        not null,
  p3_phone        text        not null,
  -- Meta
  agreed_to_rules boolean     not null default true,
  created_at      timestamptz not null default now(),
  -- All emails must be @nu.edu.pk
  constraint reg_p1_email_fmt check (p1_email ~* '^[A-Za-z][0-9]{4}@nu\.edu\.pk$'),
  constraint reg_p2_email_fmt check (p2_email ~* '^[A-Za-z][0-9]{4}@nu\.edu\.pk$'),
  constraint reg_p3_email_fmt check (p3_email ~* '^[A-Za-z][0-9]{4}@nu\.edu\.pk$'),
  constraint reg_p1_phone_fmt check (p1_phone ~ '^03[0-9]{9}$'),
  constraint reg_p2_phone_fmt check (p2_phone ~ '^03[0-9]{9}$'),
  constraint reg_p3_phone_fmt check (p3_phone ~ '^03[0-9]{9}$'),
  -- No duplicate emails within the same team submission
  constraint reg_emails_distinct check (
    lower(trim(p1_email)) <> lower(trim(p2_email)) and
    lower(trim(p1_email)) <> lower(trim(p3_email)) and
    lower(trim(p2_email)) <> lower(trim(p3_email))
  ),
  constraint reg_rules_agreed check (agreed_to_rules = true)
);

-- Keep an existing table aligned if the schema is re-run after tightening the email format.
alter table public.registrations drop constraint if exists reg_p1_email_fmt;
alter table public.registrations drop constraint if exists reg_p2_email_fmt;
alter table public.registrations drop constraint if exists reg_p3_email_fmt;
alter table public.registrations add constraint reg_p1_email_fmt check (p1_email ~* '^[A-Za-z][0-9]{4}@nu\.edu\.pk$');
alter table public.registrations add constraint reg_p2_email_fmt check (p2_email ~* '^[A-Za-z][0-9]{4}@nu\.edu\.pk$');
alter table public.registrations add constraint reg_p3_email_fmt check (p3_email ~* '^[A-Za-z][0-9]{4}@nu\.edu\.pk$');
alter table public.registrations drop constraint if exists reg_p1_phone_fmt;
alter table public.registrations drop constraint if exists reg_p2_phone_fmt;
alter table public.registrations drop constraint if exists reg_p3_phone_fmt;
alter table public.registrations add constraint reg_p1_phone_fmt check (p1_phone ~ '^03[0-9]{9}$');
alter table public.registrations add constraint reg_p2_phone_fmt check (p2_phone ~ '^03[0-9]{9}$');
alter table public.registrations add constraint reg_p3_phone_fmt check (p3_phone ~ '^03[0-9]{9}$');

-- 2. Unique VJudge team ID (case-insensitive)
create unique index if not exists reg_vjudge_uniq
  on public.registrations (lower(trim(vjudge_id)));

-- 3. Email uniqueness guard table (prevents same person joining two teams)
create table if not exists public.registration_emails (
  email           text primary key,
  registration_id uuid not null references public.registrations(id) on delete cascade
);

-- 4. Trigger function: after each team insert, lock all 3 participant emails globally
create or replace function public.fn_guard_participant_emails()
returns trigger language plpgsql security definer as $$
begin
  begin
    insert into public.registration_emails (email, registration_id) values
      (lower(trim(new.p1_email)), new.id),
      (lower(trim(new.p2_email)), new.id),
      (lower(trim(new.p3_email)), new.id);
  exception
    when unique_violation then
      raise exception
        'One or more participant emails are already registered in another team.'
        using errcode = '23505';
  end;
  return new;
end;
$$;

create trigger trg_guard_participant_emails
  after insert on public.registrations
  for each row execute function public.fn_guard_participant_emails();

-- 5. Row Level Security
alter table public.registrations       enable row level security;
alter table public.registration_emails enable row level security;

-- Allow anonymous inserts only
create policy "anon_insert_registrations"
  on public.registrations for insert to anon with check (true);

create policy "anon_insert_emails"
  on public.registration_emails for insert to anon with check (true);
