-- IEEE Xtreme Qualifier – complete Supabase setup and security migration
-- Run this entire file in Supabase Dashboard → SQL Editor.

-- Main table: one row per team.
create table if not exists public.registrations (
  id              uuid        primary key default gen_random_uuid(),
  team_name       text        not null,
  vjudge_id       text        not null,
  p1_name         text        not null,
  p1_email        text        not null,
  p1_phone        text        not null,
  p2_name         text        not null,
  p2_email        text        not null,
  p2_phone        text        not null,
  p3_name         text        not null,
  p3_email        text        not null,
  p3_phone        text        not null,
  agreed_to_rules boolean     not null default true,
  created_at      timestamptz not null default now(),
  constraint reg_team_name_fmt check (length(trim(team_name)) between 1 and 80),
  constraint reg_vjudge_fmt check (vjudge_id ~ '^[A-Za-z0-9_]+$'),
  constraint reg_p1_email_fmt check (p1_email ~* '^[A-Za-z][0-9]{6}@nu\.edu\.pk$'),
  constraint reg_p2_email_fmt check (p2_email ~* '^[A-Za-z][0-9]{6}@nu\.edu\.pk$'),
  constraint reg_p3_email_fmt check (p3_email ~* '^[A-Za-z][0-9]{6}@nu\.edu\.pk$'),
  constraint reg_p1_phone_fmt check (p1_phone ~ '^03[0-9]{9}$'),
  constraint reg_p2_phone_fmt check (p2_phone ~ '^03[0-9]{9}$'),
  constraint reg_p3_phone_fmt check (p3_phone ~ '^03[0-9]{9}$'),
  constraint reg_emails_distinct check (
    lower(trim(p1_email)) <> lower(trim(p2_email)) and
    lower(trim(p1_email)) <> lower(trim(p3_email)) and
    lower(trim(p2_email)) <> lower(trim(p3_email))
  ),
  constraint reg_rules_agreed check (agreed_to_rules = true)
);

-- Reapply validation constraints when upgrading an existing table.
alter table public.registrations drop constraint if exists reg_team_name_fmt;
alter table public.registrations drop constraint if exists reg_vjudge_fmt;
alter table public.registrations drop constraint if exists reg_p1_email_fmt;
alter table public.registrations drop constraint if exists reg_p2_email_fmt;
alter table public.registrations drop constraint if exists reg_p3_email_fmt;
alter table public.registrations drop constraint if exists reg_p1_phone_fmt;
alter table public.registrations drop constraint if exists reg_p2_phone_fmt;
alter table public.registrations drop constraint if exists reg_p3_phone_fmt;
alter table public.registrations add constraint reg_team_name_fmt check (length(trim(team_name)) between 1 and 80);
alter table public.registrations add constraint reg_vjudge_fmt check (vjudge_id ~ '^[A-Za-z0-9_]+$');
alter table public.registrations add constraint reg_p1_email_fmt check (p1_email ~* '^[A-Za-z][0-9]{6}@nu\.edu\.pk$');
alter table public.registrations add constraint reg_p2_email_fmt check (p2_email ~* '^[A-Za-z][0-9]{6}@nu\.edu\.pk$');
alter table public.registrations add constraint reg_p3_email_fmt check (p3_email ~* '^[A-Za-z][0-9]{6}@nu\.edu\.pk$');
alter table public.registrations add constraint reg_p1_phone_fmt check (p1_phone ~ '^03[0-9]{9}$');
alter table public.registrations add constraint reg_p2_phone_fmt check (p2_phone ~ '^03[0-9]{9}$');
alter table public.registrations add constraint reg_p3_phone_fmt check (p3_phone ~ '^03[0-9]{9}$');

-- Unique team ID and globally unique participant emails.
create unique index if not exists reg_vjudge_uniq
  on public.registrations (lower(trim(vjudge_id)));

create table if not exists public.registration_emails (
  email           text primary key,
  registration_id uuid not null references public.registrations(id) on delete cascade
);

-- Only the trigger may write to the email guard table.
alter table public.registration_emails enable row level security;
revoke all on public.registration_emails from anon, authenticated;
drop policy if exists "anon_insert_emails" on public.registration_emails;

-- Atomically reserve all three participant emails after a team insert.
drop trigger if exists trg_guard_participant_emails on public.registrations;

create or replace function public.fn_guard_participant_emails()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    insert into public.registration_emails (email, registration_id)
    values
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

-- Least-privilege anonymous access: insert registrations only.
alter table public.registrations enable row level security;
revoke all on public.registrations from anon, authenticated;
grant insert on public.registrations to anon;

drop policy if exists "anon_insert_registrations" on public.registrations;
drop policy if exists "anon_select_registrations" on public.registrations;
drop policy if exists "anon_update_registrations" on public.registrations;
drop policy if exists "anon_delete_registrations" on public.registrations;

create policy "anon_insert_registrations"
  on public.registrations
  for insert
  to anon
  with check (
    length(trim(team_name)) between 1 and 80
    and vjudge_id ~ '^[A-Za-z0-9_]+$'
    and p1_email ~* '^[A-Za-z][0-9]{6}@nu\.edu\.pk$'
    and p2_email ~* '^[A-Za-z][0-9]{6}@nu\.edu\.pk$'
    and p3_email ~* '^[A-Za-z][0-9]{6}@nu\.edu\.pk$'
    and p1_phone ~ '^03[0-9]{9}$'
    and p2_phone ~ '^03[0-9]{9}$'
    and p3_phone ~ '^03[0-9]{9}$'
    and agreed_to_rules = true
  );
