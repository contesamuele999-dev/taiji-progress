# Piano tecnico — Prototipo "Allenamento con Camera"

Funzione: **rilevazione del blocco + guida vocale**. L'allievo appoggia il telefono davanti a sé, esegue la forma; quando si ferma perché ha dimenticato il movimento, l'app pronuncia il nome della figura successiva.

Scope del prototipo: solo questo. Niente correzione dei dettagli (fase successiva). È la parte più affidabile e di maggior valore, e si integra nell'`index.html` esistente come nuova schermata.

---

## 1. Principio di funzionamento

Non serve "riconoscere" la forma per dare valore. Bastano due segnali:

1. **Movimento sì/no** — quanto si muove il corpo, misurato dai punti chiave della posa.
2. **Posizione nella sequenza** — un semplice indice della figura corrente (0–17 per la forma 18), che avanza manualmente o automaticamente.

Quando il movimento resta **sotto soglia per N secondi** → l'allievo è bloccato → parte l'audio col nome della figura successiva.

Tutto gira **on-device, nel browser**. Il video non lascia mai il telefono (importante per privacy e per non consumare rete).

---

## 2. Stack tecnico

| Componente | Tecnologia | Note |
|---|---|---|
| Camera | `navigator.mediaDevices.getUserMedia` | facecam frontale, `facingMode:"user"` |
| Stima posa | **MediaPipe Tasks Vision — Pose Landmarker** (CDN) | 33 keypoint, gira in-browser, WASM/GPU |
| Voce | **Web Speech API** (`speechSynthesis`, `it-IT`) per il prototipo; in fase 2 file audio pre-registrati | zero file da gestire all'inizio |
| UI | HTML/CSS già esistenti nell'`index.html` | nuova schermata, stesso stile |
| Stato sequenza | array delle 18 figure (nomi già nel progetto) | riuso `figure/forma-18/*.jpg` come riferimento visivo |

CDN MediaPipe (niente build, compatibile col tuo single-file):
```html
<script type="module">
import { FilesetResolver, PoseLandmarker }
  from "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14";
</script>
```

---

## 3. Algoritmo di rilevazione del "blocco"

Il cuore del prototipo. Misura la **velocità media dei keypoint** tra frame consecutivi.

```js
// Per ogni frame: media dello spostamento dei landmark rispetto al frame precedente
function motionScore(prev, curr) {
  let sum = 0, n = 0;
  for (let i = 0; i < curr.length; i++) {
    if (curr[i].visibility < 0.5) continue;     // ignora punti incerti
    const dx = curr[i].x - prev[i].x;
    const dy = curr[i].y - prev[i].y;
    sum += Math.hypot(dx, dy);                  // coord. normalizzate 0–1
    n++;
  }
  return n ? sum / n : 0;
}
```

Macchina a stati per evitare falsi allarmi (il Taiji è lento → molto movimento è già "quasi fermo"):

```
STATO  IN_MOVIMENTO  →  se motionScore < SOGLIA_FERMO per FERMO_MS  →  STATO BLOCCATO
STATO  BLOCCATO      →  pronuncia figura successiva, poi STATO IN_ATTESA
STATO  IN_ATTESA     →  se motionScore > SOGLIA_RIPARTI  →  avanza indice, torna IN_MOVIMENTO
```

Parametri da tarare sul campo (valori di partenza):
- `SOGLIA_FERMO` ≈ 0.004 (movimento normalizzato/frame)
- `FERMO_MS` ≈ 2500 ms (quanto deve restare fermo prima di considerarlo bloccato)
- `SOGLIA_RIPARTI` ≈ 0.010
- Smoothing: media mobile su ~5 frame per togliere il jitter.

> Nota: il Taiji ha pause **volute** (transizioni lente, momenti di radicamento). Per questo `FERMO_MS` deve essere generoso e va calibrato con un praticante reale. In più aggiungiamo un cooldown (es. 6 s) dopo ogni annuncio per non ripetere.

---

## 4. Gestione della sequenza (forma 18)

```js
const FORMA_18 = [
  { n: 1,  nome: "Inizio / Apertura" },
  { n: 2,  nome: "..." },
  // ... fino a 18 — riempire coi nomi reali delle figure
];
let idx = 0; // figura corrente

function annunciaProssima() {
  const next = FORMA_18[Math.min(idx + 1, FORMA_18.length - 1)];
  parla(`Prossima figura: ${next.nome}`);
}
```

Avanzamento: per il prototipo **manuale + automatico semplice**. L'indice avanza quando l'allievo riparte dopo un blocco, oppure con un tap. Il riconoscimento automatico preciso della figura (DTW sul video di riferimento) è fase successiva.

---

## 5. Voce — nessun file audio, lettura diretta dai nomi nell'app

La sintesi vocale del telefono (`speechSynthesis`) legge qualunque stringa al volo, quindi attinge **direttamente** all'array `figures` già presente in `index.html`. Zero asset audio.

Attenzione al formato dei tuoi nomi: nel `SEED` ogni figura è una stringa **mista pinyin + italiano**, es. `"Jingang daodui – Il guardiano pesta il mortaio"`, e il testo sta nel campo `.n` (per via di `const F=n=>({n,s:0,t:null})`). La voce `it-IT` storpierebbe il pinyin, quindi si separa sul trattino `–` e si legge **solo la parte italiana**:

```js
let voceIt = null;
function initVoce() {
  const pick = () => {
    const vs = speechSynthesis.getVoices().filter(v => v.lang.startsWith("it"));
    voceIt = vs.find(v => /natur|enhanced|premium/i.test(v.name)) || vs[0] || null;
  };
  pick();
  speechSynthesis.onvoiceschanged = pick; // su mobile le voci arrivano async
}

function parlaFigura(stringaFigura) {
  const italiano = stringaFigura.split("–").pop().trim(); // -> "Il guardiano pesta il mortaio"
  const u = new SpeechSynthesisUtterance(italiano);
  u.lang = "it-IT"; u.rate = 0.95;
  if (voceIt) u.voice = voceIt;
  speechSynthesis.cancel();      // interrompe l'annuncio precedente
  speechSynthesis.speak(u);
}
```

Due vincoli del browser da tenere a mente:
- La sintesi parte solo **dopo una prima interazione** dell'utente → far iniziare l'allenamento con un pulsante "Inizia" sblocca l'audio.
- Le voci si caricano in modo asincrono su mobile → usare `onvoiceschanged` (come sopra).

Se in futuro vuoi la pronuncia **cinese** corretta (es. *Lán zhā yī*) servirebbe una voce `zh-CN` (che però storpia l'italiano) o, solo per quei termini, file pre-registrati. Per la guida durante la pratica il nome italiano è quello utile.

---

## 6. Integrazione nell'`index.html` esistente

Aggiungere una nuova **schermata "Allenamento Camera"**, coerente con le altre:

```
[ Pannello forma 18 ]
   └─ pulsante "Allenati con la camera"
        └─ schermata camera:
             <video> live + <canvas> overlay scheletro
             badge figura corrente (immagine figure/forma-18/NN.jpg + nome)
             indicatore stato (In movimento / Bloccato)
             toggle voce on/off, slider sensibilità
```

Loop di elaborazione (≈ a 20–30 fps è sufficiente):
```js
async function loop() {
  const res = poseLandmarker.detectForVideo(video, performance.now());
  const lm = res.landmarks?.[0];
  if (lm) {
    disegnaScheletro(lm);          // feedback visivo
    const score = smooth(motionScore(prevLm, lm));
    aggiornaStato(score);          // macchina a stati del §3
    prevLm = lm;
  }
  requestAnimationFrame(loop);
}
```

---

## 7. Milestone di sviluppo

| Fase | Obiettivo | Esito verificabile |
|---|---|---|
| **M1** | Camera + Pose Landmarker che disegna lo scheletro live | vedo i punti sul mio corpo, fluido sul telefono |
| **M2** | `motionScore` + indicatore "fermo/in movimento" a schermo | il badge cambia quando mi fermo |
| **M3** | Macchina a stati + annuncio vocale figura successiva | mi fermo 3 s → l'app dice il nome giusto |
| **M4** | Pannello sensibilità + lista figure 18 + immagine corrente | taratura sul campo con un praticante |
| **M5** *(opz.)* | Avanzamento auto dell'indice al riavvio del movimento | la sequenza scorre da sola |

M1–M3 sono il prototipo dimostrabile. Tutto il resto è rifinitura.

---

## 8. Rischi e accorgimenti

- **Inquadratura**: serve figura intera → telefono appoggiato a ~2,5–3 m, in verticale o orizzontale. Aggiungere una guida di posizionamento all'avvio.
- **Rotazioni del Chen**: quando l'allievo si gira di spalle, i keypoint diventano inaffidabili → in quei tratti il `motionScore` può saltare. Mitigazione: usare solo i landmark con `visibility` alta e soglie più tolleranti.
- **Pause volute del Taiji** vs blocco reale: unica difesa è tarare `FERMO_MS` con una persona vera. Prevedere lo slider sensibilità.
- **Batteria/calore**: sessioni lunghe scaldano. Limitare a ~24 fps e offrire stop automatico.
- **Luce**: ambiente illuminato uniformemente; evitare controluce dalla finestra.

---

## 9. Privacy

Il flusso video resta **interamente sul dispositivo**: MediaPipe elabora in locale, niente upload, niente Supabase per il video. Da comunicare chiaramente all'utente nella schermata (build di fiducia).

---

## 10. Prossimo passo consigliato

Partire da **M1** come spike isolato (una pagina di test separata che apre la camera e disegna lo scheletro), per verificare prestazioni e fluidità sul telefono target prima di integrare nell'app. Se M1 gira bene, M2–M3 sono rapidi.
