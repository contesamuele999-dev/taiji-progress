# Generare minutaggio + screenshot delle figure dai video (metodo audio)

Guida per popolare automaticamente, in "Taiji Progress", i tempi e le immagini di ogni
figura di una forma, partendo da un video in cui **l'istruttore pronuncia i nomi**.
Il metodo audio è molto più preciso di quello a movimento, perché si aggancia all'istante
esatto in cui ogni nome viene detto.

---

## 1. Come registrare il video (importante)

Più segui questi punti, più i tempi saranno precisi e meno correzioni serviranno.

- **Una sola esecuzione completa** della forma, ripresa dall'inizio alla fine, senza tagli.
- **Camera ferma** (treppiede) e **persona intera** sempre nel campo.
- L'istruttore **pronuncia il nome di ogni figura a voce alta**, in modo **coerente**:
  sempre allo **stesso momento** rispetto al movimento (consigliato: **all'inizio** di ogni
  figura, subito prima di eseguirla).
- Usa **i nomi come sono nell'app** (pinyin o nome italiano), scanditi chiaramente, con una
  **piccola pausa** tra un nome e il successivo.
- Dichiara a voce **"inizio"** prima dell'apertura e **"fine"** dopo la chiusura: aiuta a
  fissare con certezza i due estremi.
- **Audio pulito**: niente musica di sottofondo, niente altre voci sovrapposte; microfono
  vicino o ambiente silenzioso.
- Va benissimo un **gruppo** che esegue insieme, purché la voce dei nomi sia ben udibile.
- Salva il file con un nome semplice (es. `forma-56.mp4`) nella cartella del progetto.

Lingua dei nomi: indifferente (pinyin o italiano), basta che siano riconoscibili e coerenti
con quelli già presenti nell'app per quella forma.

---

## 2. Prompt da incollarmi (in una sessione Cowork)

Copia il blocco qui sotto, **compila le 3 righe tra parentesi** e incollamelo. Assicurati
che il file video sia nella cartella del progetto.

```
Popola i tempi e le immagini delle figure della forma in "Taiji Progress" usando il
metodo AUDIO (l'istruttore pronuncia i nomi).

- Forma: (id forma nell'app, es. "forma-56")
- File video: (nome del file nella cartella, es. "forma-56.mp4")
- Link YouTube da impostare come video della forma: (incolla l'URL, oppure scrivi "nessuno")

Procedi così:
1. Trascrivi l'audio con i timestamp (Whisper o faster-whisper nel sandbox; lingua auto).
2. Prendi la lista delle figure di quella forma dall'app (array figures in index.html) e
   ALLINEA ogni nome pronunciato alla figura corrispondente (match fuzzy su pinyin senza
   toni o sul nome italiano). Ogni nome detto = il momento di quella figura.
3. Per il fotogramma di ogni figura, RAFFINA col movimento: parti dall'istante del nome e
   prendi il frame nella prima posizione di assestamento (minimo di movimento) subito dopo,
   così lo screenshot cade sulla posa tenuta e non su un fotogramma sfocato.
4. Estrai i frame (~480px, jpg) e salvali come FILE in figure/<id-forma>/NN.jpg
   (NON base64, per non gonfiare lo stato sincronizzato sul cloud).
5. Inserisci nell'app: const con video reale + array dei tempi (in secondi) dopo PALOSEQ,
   e una migrazione `if(!S.<flag>)` che, sulla forma giusta (se il numero di figure coincide),
   imposta f.video e per ogni figura fig.t + fig.img='figure/<id>/NN.jpg'. Preserva lo stato
   (s) delle figure. La UI mostra già la thumbnail a sinistra di ogni riga (.figthumb) e la
   modale usa x.img: non serve altro lato render.
6. Aggiorna sw.js (bump versione cache) così le nuove immagini restano disponibili offline.
7. Validazione: il mount sandbox sui file grandi è spesso TRONCATO/stantio → NON fidarti del
   node --check sul file intero; valida i blocchi modificati in isolamento e verifica le
   giunzioni con Grep/Read sul path Windows.
8. Prima di "cucire" tutto, mostrami un PROVINO (griglia con numero, m:ss e nome di ogni
   figura) per la verifica visiva; integra dopo la mia conferma.

Note: i tempi sono calcolati sul file; se la timeline di YouTube risultasse sfasata, lascia
i tempi e segnalami lo scarto. Se una figura risulta spostata, dimmelo e rigenera quel frame.
```

---

## 3. Se in un video l'istruttore NON dice i nomi

Si ripiega sul **metodo a movimento** (quello usato per la Forma 18): trovo le pause di
assestamento e le mappo alle figure. Funziona ma è approssimativo e va verificato a occhio,
soprattutto per individuare l'inizio e la fine reali della forma nel video.

---

## 4. Promemoria tecnici (per la sessione futura)

- Cartella progetto: `Taiji-progress App` (PWA single-file: index.html + manifest + sw.js).
- Le immagini delle figure vanno in `figure/<id-forma>/NN.jpg` e referenziate come percorso
  relativo nel campo `img` della figura. Quando pubblichi l'app, **carica anche la cartella
  `figure/`** insieme a index.html.
- Schema migrazioni: blocchi `if(!S.<flag>){ ...; S.<flag>=true; }` dentro la funzione di
  load, sul modello di `figPDF` / `f18autoV1`.
- Il campo `t` della figura è in **secondi** (interi); l'app mostra m:ss e il ▶ apre il video
  al secondo giusto.
