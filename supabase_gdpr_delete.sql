-- ============================================================
--  GDPR — Diritto all'oblio (art. 17)
--  Funzione RPC che consente all'utente autenticato di cancellare
--  DEFINITIVAMENTE il proprio account auth + i dati collegati.
--
--  Eseguire UNA VOLTA nell'editor SQL di Supabase.
--  L'app la richiama con: sb.rpc('delete_own_account')
-- ============================================================

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer            -- gira con privilegi elevati per poter toccare auth.users
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  -- 1) Dati applicativi dell'utente (adatta i nomi tabella alle tue reali)
  delete from public.app_state        where owner      = uid;
  delete from public.advice_requests  where student_id = uid;
  delete from public.student_notes    where student_id = uid;
  delete from public.profiles         where id         = uid;

  -- 2) Account di autenticazione (richiede security definer)
  delete from auth.users where id = uid;
end;
$$;

-- Solo gli utenti autenticati possono invocarla, e agisce solo su sé stessi (auth.uid()).
revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;

-- NOTE:
-- * Se alcune tabelle non esistono nel tuo schema, rimuovi le righe DELETE corrispondenti.
-- * In alternativa, definisci le foreign key verso auth.users con "on delete cascade"
--   e qui basterà il solo "delete from auth.users where id = uid;".
-- * Se preferisci non toccare auth.users via RPC, l'app degrada con grazia:
--   cancella comunque i dati locali e mostra il messaggio gdpr_delete_local.
