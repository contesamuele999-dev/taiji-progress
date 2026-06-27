-- ============================================================
--  Taiji Progress · Migrazione: CONTENUTI DELL'ISTRUTTORE (curriculum condiviso)
--  Esegui questo script UNA VOLTA nel SQL Editor di Supabase
--  (Dashboard Supabase → SQL Editor → New query → incolla → Run).
--  È sicuro rieseguirlo: usa "if not exists" e ricrea le policy.
--
--  A cosa serve:
--  L'istruttore puo' modificare forme, figure, esercizi, livelli/categorie,
--  video e timestamp. Queste modifiche vengono salvate qui e condivise
--  automaticamente con i SUOI allievi (quelli legati al suo instructor_id).
-- ============================================================

create table if not exists public.instructor_content (
  instructor_id uuid primary key references auth.users on delete cascade,
  data          jsonb,                      -- override del curriculum (forme, livelli, sezioni, video, timestamp)
  updated_at    timestamptz default now()
);
alter table public.instructor_content enable row level security;

-- RLS:
--  - l'istruttore gestisce (legge/scrive) SOLO la propria riga;
--  - l'allievo LEGGE la riga del proprio istruttore (in sola lettura).
drop policy if exists "ic_instr_all"     on public.instructor_content;
drop policy if exists "ic_student_read"  on public.instructor_content;

create policy "ic_instr_all" on public.instructor_content for all
  using (instructor_id = auth.uid())
  with check (instructor_id = auth.uid());

create policy "ic_student_read" on public.instructor_content for select
  using (instructor_id = (select instructor_id from public.profiles where id = auth.uid()));

-- ============================================================
--  Fatto. Nessun altro passaggio: l'app usa automaticamente questa tabella.
--  Da account istruttore vedrai i pulsanti di modifica (✎) nelle forme e nelle
--  sezioni, e potrai gestire i livelli. Le modifiche si propagano ai tuoi allievi
--  al loro prossimo accesso (o ricaricando l'app).
-- ============================================================
