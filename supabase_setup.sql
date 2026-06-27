-- ============================================================
--  Taiji Progress · Setup database Supabase  (v2 · multi-istruttore)
--  Esegui TUTTO questo script una volta sola, nel SQL Editor di Supabase
--  (Dashboard Supabase → SQL Editor → New query → incolla → Run).
--  È sicuro rieseguirlo: usa "if not exists" e ricrea le policy.
-- ============================================================

-- 1) PROFILI --------------------------------------------------
create table if not exists public.profiles (
  id            uuid primary key references auth.users on delete cascade,
  email         text,
  name          text,
  role          text not null default 'student',   -- 'student' | 'instructor'
  active        boolean not null default false,     -- l'allievo entra solo se true
  school_code   text,
  instructor_id uuid references auth.users on delete set null, -- a quale istruttore appartiene l'allievo
  invite_code   text,                               -- (solo istruttori) il proprio codice di invito
  created_at    timestamptz default now()
);
-- aggiungi le colonne nuove se la tabella esisteva già
alter table public.profiles add column if not exists instructor_id uuid references auth.users on delete set null;
alter table public.profiles add column if not exists invite_code text;
alter table public.profiles enable row level security;

-- 2) PROGRESSI (un record per utente, tutto in JSON) ----------
create table if not exists public.progress (
  user_id    uuid primary key references auth.users on delete cascade,
  data       jsonb,
  updated_at timestamptz default now()
);
alter table public.progress enable row level security;

-- 3) CODICI DI INVITO (uno o più per istruttore) --------------
create table if not exists public.invite_codes (
  code          text primary key,
  instructor_id uuid not null references auth.users on delete cascade,
  school_name   text,
  created_at    timestamptz default now()
);
alter table public.invite_codes enable row level security;

-- 4) LEZIONI (registrazioni caricate dall'istruttore) ---------
create table if not exists public.lessons (
  id            uuid primary key default gen_random_uuid(),
  instructor_id uuid not null references auth.users on delete cascade,
  lesson_date   date,
  title         text,
  video_url     text,        -- link oppure codice embed (<iframe ...>)
  created_at    timestamptz default now()
);
alter table public.lessons enable row level security;

-- 5) NOTE DEL MAESTRO PER L'ALLIEVO ---------------------------
create table if not exists public.student_notes (
  id            uuid primary key default gen_random_uuid(),
  instructor_id uuid not null references auth.users on delete cascade,
  student_id    uuid not null references auth.users on delete cascade,
  body          text not null,
  created_at    timestamptz default now()
);
alter table public.student_notes enable row level security;

-- 6) RICHIESTE DI CONSIGLIO (allievo → istruttore) ------------
create table if not exists public.advice_requests (
  id            uuid primary key default gen_random_uuid(),
  student_id    uuid not null references auth.users on delete cascade,
  instructor_id uuid references auth.users on delete set null,
  question      text not null,
  answer        text,
  created_at    timestamptz default now(),
  answered_at   timestamptz
);
alter table public.advice_requests enable row level security;

-- 7) FUNZIONE: l'utente corrente è un istruttore? -------------
create or replace function public.is_instructor()
returns boolean language sql security definer stable set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'instructor');
$$;

-- 8) REGOLE DI SICUREZZA (RLS) --------------------------------
-- PROFILI: ognuno vede sé stesso; l'istruttore vede i propri allievi.
drop policy if exists "profiles_self_read"    on public.profiles;
drop policy if exists "profiles_instr_read"   on public.profiles;
drop policy if exists "profiles_self_update"  on public.profiles;
drop policy if exists "profiles_instr_update" on public.profiles;
create policy "profiles_read" on public.profiles for select
  using (id = auth.uid() or instructor_id = auth.uid());
create policy "profiles_self_update"  on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());
create policy "profiles_instr_update" on public.profiles for update
  using (instructor_id = auth.uid()) with check (instructor_id = auth.uid());

-- Trigger anti-escalation: un allievo può cambiare nome/email e
-- spostarsi a un ALTRO istruttore (solo verso un codice di invito valido);
-- mai ruolo / attivazione / proprio codice. Solo gli istruttori possono tutto.
create or replace function public.protect_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_instructor() then
    new.role          := old.role;
    new.active        := old.active;
    new.invite_code   := old.invite_code;
    -- l'allievo può cambiare il proprio istruttore solo verso uno reale
    -- (cioè un instructor_id presente nella tabella dei codici di invito)
    if new.instructor_id is distinct from old.instructor_id
       and not exists (select 1 from public.invite_codes ic
                       where ic.instructor_id = new.instructor_id) then
      new.instructor_id := old.instructor_id;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_protect on public.profiles;
create trigger profiles_protect before update on public.profiles
  for each row execute procedure public.protect_profile();

-- PROGRESSI: l'allievo gestisce i propri; l'istruttore legge quelli dei suoi allievi.
drop policy if exists "progress_self_all"   on public.progress;
drop policy if exists "progress_instr_read" on public.progress;
create policy "progress_self_all" on public.progress for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "progress_instr_read" on public.progress for select
  using (user_id in (select id from public.profiles where instructor_id = auth.uid()));

-- CODICI DI INVITO: leggibili da tutti (servono in fase di registrazione);
-- ogni istruttore gestisce solo i propri.
drop policy if exists "invite_read"  on public.invite_codes;
drop policy if exists "invite_manage" on public.invite_codes;
create policy "invite_read"   on public.invite_codes for select using (true);
create policy "invite_manage" on public.invite_codes for all
  using (instructor_id = auth.uid()) with check (instructor_id = auth.uid());

-- LEZIONI: l'istruttore gestisce le proprie; l'allievo legge quelle del suo istruttore.
drop policy if exists "lessons_instr"   on public.lessons;
drop policy if exists "lessons_student" on public.lessons;
create policy "lessons_instr"   on public.lessons for all
  using (instructor_id = auth.uid()) with check (instructor_id = auth.uid());
create policy "lessons_student" on public.lessons for select
  using (instructor_id = (select instructor_id from public.profiles where id = auth.uid()));

-- NOTE: l'istruttore gestisce le proprie; l'allievo legge le sue.
drop policy if exists "notes_instr"   on public.student_notes;
drop policy if exists "notes_student" on public.student_notes;
create policy "notes_instr"   on public.student_notes for all
  using (instructor_id = auth.uid()) with check (instructor_id = auth.uid());
create policy "notes_student" on public.student_notes for select
  using (student_id = auth.uid());

-- CONSIGLI: l'allievo crea/legge i propri; l'istruttore legge/risponde ai suoi.
drop policy if exists "advice_student_ins" on public.advice_requests;
drop policy if exists "advice_student_sel" on public.advice_requests;
drop policy if exists "advice_instr"       on public.advice_requests;
create policy "advice_student_ins" on public.advice_requests for insert
  with check (student_id = auth.uid());
create policy "advice_student_sel" on public.advice_requests for select
  using (student_id = auth.uid());
create policy "advice_instr" on public.advice_requests for all
  using (instructor_id = auth.uid()) with check (instructor_id = auth.uid());

-- 9) AUTO-CREAZIONE del profilo alla registrazione ------------
--    Ogni nuovo iscritto parte come 'student', NON attivo, legato
--    all'istruttore del codice usato (instructor_id nei metadati).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare iid uuid;
begin
  begin iid := (new.raw_user_meta_data->>'instructor_id')::uuid; exception when others then iid := null; end;
  insert into public.profiles (id, email, name, role, active, school_code, instructor_id)
  values (
    new.id, new.email,
    coalesce(new.raw_user_meta_data->>'name',''),
    'student', false,
    new.raw_user_meta_data->>'school_code',
    iid
  );
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
--  DOPO L'ESECUZIONE — diventare istruttore e creare il codice
-- ============================================================
-- 1) Registrati dall'app come fossi un allievo (con un codice qualsiasi).
-- 2) Promuoviti a istruttore (sostituisci la tua email):
--
--      update public.profiles
--      set role = 'instructor', active = true
--      where email = 'TUA_EMAIL@esempio.com';
--
-- 3) Crea il TUO codice di invito e collegalo al tuo profilo:
--
--      -- trova il tuo id:
--      -- select id from public.profiles where email = 'TUA_EMAIL@esempio.com';
--
--      insert into public.invite_codes (code, instructor_id, school_name)
--      values ('SCUOLA-CHEN-MARIO', '<IL-TUO-ID>', 'Scuola Chen di Mario');
--
--      update public.profiles set invite_code = 'SCUOLA-CHEN-MARIO'
--      where id = '<IL-TUO-ID>';
--
--  Ogni istruttore ripete i punti 2-3 con un PROPRIO codice diverso.
--  Gli allievi che si registrano con quel codice verranno legati a lui
--  e vedranno SOLO le sue lezioni, le sue note e potranno chiedergli consiglio.
-- ============================================================
