# Guida: login, cloud e dashboard maestro

Questa guida ti porta da "app in locale" a "web app con login per i tuoi allievi" in 4 passi.
Tutto gratuito per i tuoi numeri. Tempo richiesto: ~15 minuti.

---

## Passo 1 — Pubblica l'app online (hosting)

Serve un indirizzo web dove gli allievi aprono l'app. Consigliato: **Netlify** (gratis, senza carta).

1. Vai su https://app.netlify.com e crea un account.
2. Scegli "Add new site" → "Deploy manually".
3. Trascina la **cartella** del progetto (quella con `index.html`, `sw.js`, `manifest.webmanifest`, `icon.svg`).
4. Netlify ti dà un indirizzo tipo `https://taiji-progress.netlify.app`. Quello è il link da dare agli allievi.

> Alternative equivalenti: Vercel, Cloudflare Pages, GitHub Pages.
> Gli allievi aprono il link sul telefono e fanno "Aggiungi a schermata Home": l'app si installa come una vera app (icona, schermo intero, offline).

---

## Passo 2 — Crea il progetto Supabase (la "cassaforte" dei dati)

1. Vai su https://supabase.com e crea un account.
2. "New project": scegli un nome (es. `taiji-progress`), una password per il database (salvala) e una region vicina (es. Frankfurt).
3. Attendi ~2 minuti che il progetto sia pronto.

---

## Passo 3 — Prepara il database

1. Nel progetto Supabase, menu a sinistra → **SQL Editor** → **New query**.
2. Apri il file `supabase_setup.sql` (in questa stessa cartella), copia **tutto** il contenuto e incollalo.
3. Premi **Run**. Deve comparire "Success". Questo crea le tabelle, le regole di sicurezza e l'attivazione automatica dei profili.

---

## Passo 4 — Collega l'app a Supabase

1. In Supabase: menu a sinistra → **Project Settings** (icona ingranaggio) → **API**.
2. Copia due valori:
   - **Project URL** (es. `https://abcdxyz.supabase.co`)
   - **anon public** key (una chiave lunga; è pubblica, va bene nel codice)
3. Apri `index.html` e cerca il blocco **CONFIGURA QUI** (in alto nella parte `<script>`, intorno alla riga con `SUPA_URL`). Sostituisci:

   ```js
   const SUPA_URL  = 'INCOLLA_QUI_URL_PROGETTO';   // ← Project URL
   const SUPA_KEY  = 'INCOLLA_QUI_CHIAVE_ANON';    // ← anon public key
   const INVITE_CODE = 'SCUOLA-CHEN';              // ← scegli tu il codice di invito
   ```

4. Salva il file e ricarica il sito su Netlify (ripeti il "Deploy manually" trascinando di nuovo la cartella aggiornata).

> Finché restano i segnaposto `INCOLLA_QUI...`, l'app continua a funzionare in locale **senza** login: utile per provarla.

---

## Renditi "maestro" e crea il tuo codice di invito

L'app ora supporta **più istruttori**, ognuno con un **proprio codice di invito**: gli allievi che si registrano con quel codice vengono legati a quell'istruttore e vedono solo le sue lezioni, le sue note e possono chiedergli consiglio.

1. Apri l'app pubblicata, vai su "Registrati", e crea il **tuo** account usando un codice qualsiasi.
2. Torna in Supabase → **SQL Editor** ed esegui (con la tua email):

   ```sql
   update public.profiles
   set role = 'instructor', active = true
   where email = 'TUA_EMAIL@esempio.com';
   ```

3. Crea il **tuo** codice di invito e collegalo al profilo (trova prima il tuo id con `select id from public.profiles where email='TUA_EMAIL@esempio.com';`):

   ```sql
   insert into public.invite_codes (code, instructor_id, school_name)
   values ('SCUOLA-CHEN-MARIO', '<IL-TUO-ID>', 'Scuola Chen di Mario');

   update public.profiles set invite_code = 'SCUOLA-CHEN-MARIO'
   where id = '<IL-TUO-ID>';
   ```

4. Ricarica l'app: in alto trovi **👥 Allievi** (la dashboard) e in cima la scheda con il **tuo codice di invito** da condividere.

> Ogni altro istruttore ripete i punti 2-3 con un proprio codice diverso. Il vecchio `INVITE_CODE` nel file `index.html` resta come riserva: se un allievo lo usa, viene registrato ma senza istruttore collegato (poi puoi assegnarlo a mano).

---

## Come funziona, in breve

- **Allievo**: apre il link → "Registrati" con nome, email, password e **codice di invito** del suo istruttore → resta "in attesa" finché il maestro non lo attiva.
- **Tu (maestro)**: dalla dashboard **👥 Allievi** vedi i tuoi iscritti, li **attivi/disattivi** con un tocco, vedi il **riepilogo progressi** di ciascuno e puoi lasciargli **note** (lode / cosa migliorare / compiti). Nella scheda **Consigli** rispondi alle domande degli allievi.
- **Lezioni**: nella sezione **課 Lezioni** carichi un link o un embed del video della lezione; viene mostrata agli allievi col nome automatico "[giorno della settimana] [data]".
- **Allievo, nella sezione Lezioni**: vede le registrazioni, legge le **note del maestro** e può **chiedere un consiglio** all'istruttore.
- **Profilo**: ognuno può modificare **nome, email e password** dal pulsante 👤 Profilo.
- **Dati**: i progressi di ogni allievo sono salvati in cloud, separati e protetti (ognuno vede i propri; l'istruttore legge quelli dei suoi allievi). Si ritrovano cambiando dispositivo.
- **Lingua e tema**: in alto (menu ☰ su mobile) ogni utente sceglie la lingua (IT/EN/DE/FR/ES) e il tema colore; le scelte restano salvate.

## Risoluzione problemi

- **"Attivo" un allievo, l'app dice "accesso aggiornato" ma in tabella `active` resta false**: avevi un vecchio trigger di protezione che annullava la modifica. Rimuovilo (la protezione resta garantita dalle regole RLS) eseguendo nel SQL Editor:

  ```sql
  drop trigger if exists profiles_protect on public.profiles;
  drop policy  if exists "profiles_self_update" on public.profiles;
  ```

- **L'app dice "accesso aggiornato" ma l'allievo resta `false`** (mentre la scrittura diretta in SQL funziona): manca la regola di scrittura per il maestro. Verifica con `select policyname, cmd from pg_policies where tablename='profiles';` e, se non c'è `profiles_instr_update` (UPDATE), creala:

  ```sql
  drop policy if exists "profiles_instr_update" on public.profiles;
  create policy "profiles_instr_update" on public.profiles
    for update using (public.is_instructor()) with check (public.is_instructor());
  ```

- **"email rate limit exceeded" alla registrazione**: disattiva la conferma via email (non serve, approvi tu): Authentication → Sign In / Providers → Email → spegni "Confirm email" → Save. Gli allievi già registrati e non confermati puoi confermarli in Authentication → Users.
- **Non vedi il pulsante 👥 Allievi**: il tuo profilo non è ancora `role='instructor'`. Esegui di nuovo la `update` con la tua email esatta e ricarica l'app.

## Note e limiti (onestà)

- Il **codice di invito** è visibile a chi ispeziona il codice della pagina: serve a scoraggiare, non è una password segreta. La sicurezza vera è che nessuno entra senza la tua attivazione.
- Se un allievo usa l'app **offline**, le modifiche si sincronizzano quando torna online; al rientro l'app carica la versione in cloud. Per la pratica quotidiana online non è un problema, ma evitiamo lunghi periodi offline con modifiche su due dispositivi diversi.
- I **pagamenti** restano gestiti da te a mano (attiva/disattiva). Se in futuro vuoi pagamenti automatici (Stripe), si può aggiungere.
