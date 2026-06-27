-- ============================================================
--  Taiji Progress · Migrazione: RUOLO ADMIN (gestione istruttori)
--  Esegui questo script UNA VOLTA nel SQL Editor di Supabase
--  (Dashboard Supabase → SQL Editor → New query → incolla → Run).
--  È sicuro rieseguirlo: ricrea funzioni, policy e trigger con "or replace".
--
--  A cosa serve:
--  Introduce un terzo ruolo, 'admin'. L'admin (tu) può:
--    • vedere TUTTI i profili (allievi e istruttori);
--    • promuovere un account a 'instructor' o riportarlo a 'student'
--      (= aggiungere / rimuovere account istruttore);
--    • attivare/disattivare qualsiasi account.
--  Gli istruttori NON possono promuoversi da soli ad admin/instructor:
--  solo un admin può assegnare i ruoli 'admin' e 'instructor'.
-- ============================================================

-- 0) Ruoli ammessi (documentazione): 'student' | 'instructor' | 'admin'

-- 1) Funzione: l'utente corrente è admin? ---------------------
create or replace function public.is_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- 2) RLS PROFILI: l'admin legge e modifica TUTTI i profili ----
drop policy if exists "profiles_admin_read"   on public.profiles;
drop policy if exists "profiles_admin_update" on public.profiles;
create policy "profiles_admin_read"   on public.profiles for select
  using (public.is_admin());
create policy "profiles_admin_update" on public.profiles for update
  using (public.is_admin()) with check (public.is_admin());

-- 3) Trigger anti-escalation aggiornato -----------------------
--    - allievo: come prima (non cambia ruolo/attivazione/codice);
--    - istruttore: NON puo' assegnare i ruoli 'admin' o 'instructor';
--    - admin: puo' tutto.
create or replace function public.protect_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.is_admin() then
    return new;                       -- l'admin puo' modificare qualsiasi campo
  end if;

  if public.is_instructor() then
    if new.role is distinct from old.role
       and new.role in ('admin','instructor') then
      new.role := old.role;
    end if;
    if new.role = 'admin' then new.role := old.role; end if;
    return new;
  end if;

  -- allievo (o ruolo sconosciuto): blocco completo dei campi sensibili
  new.role          := old.role;
  new.active        := old.active;
  new.invite_code   := old.invite_code;
  if new.instructor_id is distinct from old.instructor_id
     and not exists (select 1 from public.invite_codes ic
                     where ic.instructor_id = new.instructor_id) then
    new.instructor_id := old.instructor_id;
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_protect on public.profiles;
create trigger profiles_protect before update on public.profiles
  for each row execute function public.protect_profile();

-- 4) NOMINA IL PRIMO ADMIN ------------------------------------
--    Esegui questa riga UNA VOLTA, sostituendo l'email con la TUA.
--    (Devi prima esserti registrato/loggato almeno una volta nell'app.)
--
--    update public.profiles set role = 'admin'
--      where email = 'umasterinfo@gmail.com';
--
--    Verifica:
--    select id, email, role from public.profiles where role = 'admin';

-- ============================================================
--  Fatto. Da un account con ruolo 'admin' comparira' in alto il
--  pulsante «管 Admin» per gestire gli account istruttori.
-- ============================================================

-- ----------------------------------------------------------------
--  PROMUOVERE / RIMUOVERE ISTRUTTORI MANUALMENTE (alternativa SQL)
--
--   -- rendi istruttore un account esistente:
--   update public.profiles set role='instructor', active=true
--     where email='nuovo.istruttore@example.com';
--
--   -- (consigliato) crea anche il suo codice di invito personale:
--   insert into public.invite_codes (code, instructor_id, school_name)
--   select 'SCUOLA-XYZ', id, 'Nome scuola' from public.profiles
--     where email='nuovo.istruttore@example.com'
--   on conflict (code) do nothing;
--
--   -- riporta un istruttore a semplice allievo:
--   update public.profiles set role='student' where email='ex.istruttore@example.com';
-- ----------------------------------------------------------------
