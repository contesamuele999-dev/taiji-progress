-- ============================================================
--  Taiji Progress · Migrazione: HARDENING SICUREZZA
--  Esegui questo script UNA VOLTA nel SQL Editor di Supabase.
--  È sicuro rieseguirlo.
--
--  Cosa fa:
--   1) Vincola la colonna "role" ai soli valori validi.
--   2) (Promemoria) attiva la conferma email in Auth.
-- ============================================================

-- 1) CHECK sui ruoli ammessi ----------------------------------
--    Impedisce che un record abbia un ruolo diverso da questi tre.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_role_chk'
  ) then
    alter table public.profiles
      add constraint profiles_role_chk
      check (role in ('student','instructor','admin'));
  end if;
end$$;

-- Verifica:
--   select conname, pg_get_constraintdef(oid)
--     from pg_constraint where conrelid = 'public.profiles'::regclass;

-- 2) CONFERMA EMAIL (da fare nel pannello, non via SQL) -------
--    Dashboard Supabase → Authentication → Providers → Email
--    → attiva "Confirm email".
--    Così un utente non può registrarsi con l'email di un altro
--    senza avere accesso alla casella di posta.

-- ============================================================
--  Nota: il codice di invito "fallback" (SCUOLA-CHEN) è stato
--  rimosso dall'app. Ogni nuovo allievo deve usare il codice
--  PERSONALE di un istruttore reale (tabella invite_codes).
--  Quando promuovi un istruttore dal pannello admin, l'app gli
--  crea automaticamente un codice personale.
-- ============================================================
