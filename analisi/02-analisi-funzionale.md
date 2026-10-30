# 02 — Analisi funzionale

- **Stato:** ✅ approvata (2026-10-24)
- **Ultimo aggiornamento:** 2026-10-24

## 1. Utenti

| Utente | Descrizione | Obiettivi |
|---|---|---|
| Bambina (utente principale) | 8 anni, legge ma preferisce le immagini | Disegnare, scrivere, decorare, ritrovare i propri disegni |
| Genitore | Configura il tablet, supervisiona | Esportare/stampare i disegni, sapere che l'app è sicura |

## 2. Aree funzionali (da dettagliare)

1. **Foglio e disegno a mano libera** — pennelli, colori, spessori, gomma,
   annulla/ripeti, cancella tutto.
2. **Scritte** — inserire, modificare, spostare, ingrandire, ruotare, colori e
   font.
3. **Galleria** — elenco disegni, nuovo, apri, duplica, rinomina, elimina,
   esporta/condividi.
4. **Sfondi, adesivi, forme** — tipi di foglio, catalogo adesivi, forme
   geometriche, eventuali disegni da colorare.

Per ogni area scriveremo: storie utente, criteri di accettazione, bozza
dell'interfaccia (wireframe in `risorse/`), priorità (MVP / dopo).

## 3. Coinvolgere l'utente finale

Prima di scrivere le storie utente, una breve "intervista" con la bambina
(meglio se giocando):

- Cosa ti piace disegnare? Cosa scrivi sui tuoi disegni?
- Quali app o giochi di disegno hai già usato? Cosa ti piaceva e cosa no?
- Disegni con il dito o con la penna?
- Che colori e "pennelli magici" vorresti? (glitter, arcobaleno, neon...)
- Che adesivi vorresti? (animali, cuori, stelle, emoji...)
- Cosa vuoi fare quando un disegno è finito? (tenerlo, mandarlo ai nonni,
  stamparlo...)
- Come vorresti che si chiamasse l'app? 🙂

Utile anche **osservarla** mentre usa un'app di disegno esistente e annotare
dove si blocca o cosa cerca.

## 4. Decisioni funzionali

> Ogni decisione ha un codice `F-xx`. Le decisioni architetturali di
> riferimento sono in [`01-analisi-architetturale.md`](01-analisi-architetturale.md).

### Struttura e navigazione

#### F-01 — Schermata iniziale: la galleria

- **Stato:** ✅ approvata (2026-10-24)
- All'apertura l'app mostra la **galleria**: miniature dei disegni, dal più
  recente (in alto a sinistra) al più vecchio.
- Un pulsante **"+" grande e colorato**, sempre in primo piano, crea un foglio
  nuovo con un solo tocco.
- I **fogli lasciati completamente vuoti** non vengono salvati: uscendo
  dall'editor senza aver disegnato nulla, il foglio sparisce e la galleria
  non si riempie di fogli bianchi.

#### F-02 — Nuovo foglio: bianco, subito

- **Stato:** ✅ approvata (2026-10-24)
- Toccando "+" si apre subito l'editor con un **foglio bianco**, senza
  passaggi intermedi.
- Lo **sfondo** (righe, quadretti, colore...) si cambia in qualsiasi momento
  dall'editor con il pulsante **"Foglio"**, che mostra le miniature degli
  sfondi disponibili. Cambiare sfondo non tocca il disegno (livello separato,
  AD-04) ed è annullabile.
- L'orientamento del foglio è quello del tablet al momento del tocco su "+"
  (D-05).

#### F-03 — Disposizione dell'editor

- **Stato:** ✅ approvata (2026-10-24)
- Tre zone fisse: **barra azioni** in alto, **strumenti** e **colori +
  spessore** ai lati (orizzontale) o in basso (verticale).

```
ORIZZONTALE
┌───────────────────────────────────────────────────────────┐
│ [🏠]  [↶] [↷]                 [📄 Foglio] [🔒] [🖨️] [⋯]   │ ← barra azioni
├─────┬───────────────────────────────────────────────┬─────┤
│ ✏️  │                                               │ 🔴  │
│ 🖌️  │                                               │ 🟠  │
│ 🖍️  │                                               │ 🟡  │
│ 🧽  │                 FOGLIO                        │ 🟢  │
│ 🔤  │                                               │ 🔵  │
│ ⭐  │                                               │ 🟣  │
│ ⬛  │                                               │ ⚫  │
│ ⬚   │                                               │ ● ● │
└─────┴───────────────────────────────────────────────┴─────┘
 strumenti                                         colori + spessore

VERTICALE
┌─────────────────────────────┐
│ [🏠] [↶][↷]   [📄][🔒][🖨️][⋯] │
├─────────────────────────────┤
│           FOGLIO            │
├─────────────────────────────┤
│ 🔴🟠🟡🟢🔵🟣⚫   ● ● ●       │ ← colori + spessore
│ ✏️ 🖌️ 🖍️ 🧽 🔤 ⭐ ⬛ ⬚        │ ← strumenti
└─────────────────────────────┘
```

- **Barra azioni:** 🏠 galleria (il disegno è già salvato), ↶ ↷
  annulla/ripeti, 📄 sfondo del foglio, 🔒 blocca rotazione, 🖨️ stampa,
  ⋯ salva in galleria / condividi.
- Strumento e colore attivi sempre evidenziati.
- Target touch **≥ 56 dp**.
- **Opzione "Mancina/o"** nella pagina genitori: scambia le colonne di
  strumenti e colori.
- Dalla v1.1 gli strumenti sono raggruppati in categorie (F-20).
- Altre impostazioni di personalizzazione: da pensare in futuro.

#### F-04 — Strumenti di disegno della v1

- **Stato:** ✅ approvata (2026-10-24)

| Strumento | Tratto | Spessore | Versione |
|---|---|---|---|
| ✏️ Matita | Sottile, preciso, leggera texture grafite | Costante | v1 |
| 🖊️ Pennarello | Pieno, coprente, bordi netti | Costante | v1 |
| 🖌️ Pennello | Morbido | Variabile con la velocità (AD-07) | v1 |
| 🖍️ **Pastello a cera** | Granuloso, con trama: **lo strumento "firma" dell'app** | Costante | v1 |
| 🌈 **Arcobaleno** | Il colore cambia lungo il tratto seguendo i colori dell'arcobaleno (ignora il colore selezionato) | Costante | v1 (richiesto dalla bambina) |
| 🧽 Gomma | Vedi AD-05 | Dallo spessore selezionato | v1 |
| 🖍️ Evidenziatore | Semitrasparente | Costante, largo | dopo la v1 |
| ✨ Altri pennelli magici | Glitter, neon, stelline... | — | dopo la v1 (da chiedere alla bambina) |

- Il **colore di sfondo** del foglio si sceglie dal pulsante "Foglio" (F-02),
  non serve uno strumento "riempi foglio" separato.
- Il **pastello a cera** e l'**arcobaleno** entrano nel prototipo tecnico per
  misurarne le prestazioni (trama e colore variabile).

#### F-05 — Colori

- **Stato:** ✅ approvata (2026-10-24)
- **12 colori fissi** sempre visibili come grandi pallini: rosso, arancione,
  giallo, verde chiaro, verde scuro, azzurro, blu, viola, rosa, marrone,
  nero, bianco.
- Pallino **"🎨 altri colori"**: griglia di circa 40 colori predefiniti, con
  **toni della pelle**, grigi, tinte pastello chiare e colori scuri.
- **Nessun selettore libero** (ruota HSV, cursori RGB).
- Il colore scelto dalla griglia compare in un pallino **"ultimo colore"**
  accanto ai 12 fissi.
- **Contagocce** (prendere un colore dal foglio): dopo la v1.

#### F-06 — Spessore

- **Stato:** ✅ approvata (2026-10-24)
- **4 spessori** (sottile, medio, grosso, extra-grosso), mostrati come
  pallini di grandezza crescente **nel colore selezionato**.
- **Ogni strumento ricorda il proprio spessore.** Valori iniziali: matita
  sottile; pennarello, pastello a cera, arcobaleno medio; pennello grosso;
  gomma grossa.
- Le misure reali si tarano nel prototipo sul tablet di riferimento.
- Strumento, colore e spessori scelti sono **ricordati** tra una sessione e
  l'altra (`settings.json`, AD-13).

### Scritte

#### F-07 — Inserire e modificare una scritta

- **Stato:** ✅ approvata (2026-10-24)
- **Inserire:** strumento 🔤 Testo → tocco sul foglio → riquadro con cursore
  e tastiera (il foglio scorre se la tastiera coprirebbe il punto) → si
  scrive nel **colore selezionato** → tocco fuori o ✓ per confermare.
- **Modifica (2026-10-24, confermata sul tablet):** invece di far scorrere il
  foglio, il testo si scrive in una casella **sopra la tastiera** e la scritta
  compare in tempo reale sul foglio; il foglio non cambia mai forma.
- Testo **su più righe** (Invio), **centrato** nel riquadro.
- **Selezione:** toccando la scritta compare una cornice con:
  maniglia ⟳ per ruotare, angolo ◢ per ingrandire, trascinamento interno per
  spostare, pulsanti ✏️ modifica testo, 🎨 colore/carattere, 🗑️ elimina.
  Tutto con **un dito solo** (AD-07).
- **Regola del tocco:** un tocco su scritte, adesivi o forme li **seleziona**
  solo se lo strumento attivo è Testo, Adesivi, Forme o Seleziona; con gli
  strumenti di disegno il tocco **disegna sopra**. Così il tocco non è mai
  ambiguo (precisazione di AD-03).

#### F-08 — Caratteri delle scritte

- **Stato:** ✅ approvata (2026-10-24)
- 4 caratteri inclusi nell'app, tutti **SIL OFL 1.1** (presenza della
  licenza OFL verificata nel repository di Google Fonts il 2026-10-24):

| Carattere | Stile | Uso |
|---|---|---|
| **Andika** (predefinito) | Stampato chiaro | Pensato per chi impara a leggere |
| **Playwrite IT Moderna** | Corsivo scolastico italiano | Il corsivo che si impara a scuola |
| **Fredoka** | Tondo, "cicciotto" | Titoli e scritte divertenti |
| **Comic Neue** | Fumetto | Dialoghi, nuvolette |

- Nel menu 🎨 ogni carattere è mostrato come anteprima della parola "Ciao".
- **Dimensione** solo con la maniglia ◢ (nessun menu numerico); la scritta
  nasce di una grandezza comoda da leggere.
- **Colore**: quello selezionato, modificabile dopo con 🎨.
- **Nessuno stile aggiuntivo** (grassetto, corsivo, sottolineato,
  allineamenti).

### Galleria

#### F-09 — Galleria e azioni sui disegni

- **Stato:** ✅ approvata (2026-10-24)

```
┌──────────────────────────────────────────────────────┐
│ Pastello                              [🗑️]  [👪]     │
├──────────────────────────────────────────────────────┤
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐   │
│  │  ➕  │  │ 🖼️   │  │ 🖼️   │  │ 🖼️   │  │ 🖼️   │   │
│  │      │  │    ⋯ │  │    ⋯ │  │    ⋯ │  │    ⋯ │   │
│  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘   │
│   nuovo      oggi      ieri     12 ott    10 ott     │
└──────────────────────────────────────────────────────┘
```

- **Tocco su una miniatura** → apre il disegno.
- **Pulsante ⋯** su ogni miniatura → menu a grandi icone:
  📋 Duplica · 🖼️ Salva nella galleria del tablet · 🖨️ Stampa ·
  📤 Condividi (cancello genitori) · 🗑️ Elimina (va nel cestino, **senza
  conferma** perché recuperabile).
- **Nessuna pressione prolungata** (gesto nascosto).
- **Nessun titolo** nella v1: sotto la miniatura la data relativa ("oggi",
  "ieri", "12 ott").
- **Barra in alto:** 🗑️ Cestino (ripristino libero, svuotamento con cancello
  genitori) e 👪 Pagina genitori (cancello genitori).

### Sfondi, adesivi, forme

#### F-10 — Sfondi del foglio

- **Stato:** ✅ approvata (2026-10-24)
- Scelti dal pulsante 📄 "Foglio" (F-02). Nella v1, come **primo pacchetto
  incluso** (AD-17):

| Sfondo | Descrizione |
|---|---|
| ⬜ Bianco | Predefinito |
| 🎨 Colorato | Tinta unita dalla tavolozza (F-05) |
| 📏 Righe | Righe orizzontali azzurrine, margine rosso a sinistra |
| 🔲 Quadretti grandi | ~1 cm, come il quaderno "di prima" |
| ▫️ Quadretti piccoli | ~5 mm |
| ⠿ Puntini | Griglia di punti leggeri |

- Righe, quadretti e puntini si **combinano con un colore di fondo**.
- Misure **proporzionate al foglio**, tarate in modo che la stampa su A4
  somigli al quaderno.
- **Sfondi illustrati** (cielo e prato, spiaggia, spazio...): dopo la v1, come
  nuovi pacchetti.

#### F-11 — Adesivi

- **Stato:** ✅ approvata (2026-10-24)
- Set di partenza: **Fluent Emoji** (Microsoft), stile **Flat** (vettoriale
  SVG), licenza **MIT** (licenza del repository verificata il 2026-10-24;
  verificare i singoli file prima dell'inclusione).
- **Selezione di ~150–200 adesivi** in categorie con icona, ognuna un
  pacchetto (AD-17): 🐶 animali · 🌸 natura e meteo · 🍓 cibo · ❤️ cuori e
  stelle · 😀 facce · 🎒 scuola e oggetti · 🚗 mezzi · 🎉 feste.
- **Uso:** ⭐ Adesivi → pannello con le categorie → tocco sull'adesivo →
  tocco sul foglio dove posizionarlo. Poi si sposta/ingrandisce/ruota come le
  scritte (F-07).
- **Dopo la v1:** pacchetto di adesivi disegnati da noi (magari dalla
  bambina).
- Alternative valutate: Noto Emoji (Apache-2.0/OFL, stile "da telefono"),
  Twemoji (CC-BY 4.0), OpenMoji (CC BY-SA 4.0).

#### F-12 — Forme

- **Stato:** ✅ approvata (2026-10-24)
- Forme v1: ⚪ cerchio/ovale · ⬜ quadrato/rettangolo · 🔺 triangolo ·
  ⭐ stella (5 punte) · ❤️ cuore · 📏 linea dritta · ➡️ freccia.
- **Creazione:** ⬛ Forme → scelta della forma → **trascinamento con un
  dito** dal punto di appoggio al punto di rilascio; usa colore e spessore
  selezionati. Poi si modifica come scritte e adesivi (F-07).
- Interruttore **○ solo contorno / ● piena** (riempimento dello stesso colore
  del contorno).
- **Aggancio leggero ("calamita"):** vicino alle proporzioni 1:1 la forma
  scatta a cerchio/quadrato perfetto; la linea scatta a orizzontale,
  verticale o 45°.

#### F-13 — Strumento Seleziona (lazo)

- **Stato:** ✅ approvata (2026-10-24) — **nella v1**
- ⬚ Seleziona → si disegna un contorno (linea tratteggiata, si chiude da sola
  al rilascio) → la selezione riceve la cornice di F-07: sposta, ingrandisci,
  ruota, elimina, più **📋 Duplica**.
- **Cosa è "dentro":** un tratto se la **maggior parte dei suoi punti** è
  dentro il contorno; scritte, adesivi e forme se il **loro centro** è dentro.
- Tutte le operazioni sono comandi annullabili (AD-06).

### Pagina genitori

#### F-14 — Contenuti della pagina genitori

- **Stato:** ✅ approvata (2026-10-24)
- Accesso da 👪 nella galleria, dopo il cancello genitori (D-08). Pagina a
  elenco con testo normale (è per adulti). Uscendo, il cancello va **rifatto**
  la volta successiva.

| Sezione | Contenuto | Versione |
|---|---|---|
| ⚙️ Impostazioni | Lingua (AD-12) · Mancina/o (F-03) · Suoni · Vibrazione (F-15) | v1 |
| 🗑️ Cestino | Svuota cestino (AD-09) | v1 |
| 🔒 Tenere la bambina nell'app | Guida al blocco app sullo schermo (AD-16) | v1 |
| ℹ️ Informazioni | Versione, dispositivo, Android, "Copia informazioni per la segnalazione" (AD-02) | v1 |
| 🔗 Link | Codice sorgente, segnala un problema, informativa privacy (AD-16) | v1 |
| 📜 Crediti e licenze | Librerie, caratteri, adesivi (AD-13, AD-17) | v1 |
| 💾 Backup | Esporta/importa tutti i disegni in `.zip` (AD-09) | dopo la v1 |
| 📦 Catalogo | Scarica nuovi pacchetti (AD-17) | dopo la v1 |

### Esperienza

#### F-15 — Suoni, vibrazione, primo avvio

- **Stato:** ✅ approvata (2026-10-24)
- **Suoni** brevi e delicati solo nei momenti chiave: "pop" adesivo
  appoggiato, "fruscio" elemento nel cestino, "ding" salvataggio in galleria
  o stampa. **Nessun suono durante il disegno**, nessuna musica. Suoni con
  licenza **CC0** inclusi nell'app. Attivi di default, disattivabili dalla
  pagina genitori.
- **Vibrazione** leggerissima quando una forma/linea scatta (F-12) e al cambio
  strumento. Disattivabile dalla pagina genitori.
- **Primo avvio:** nessun tutorial né schermata di benvenuto. Galleria vuota
  con il "+" che "respira" (animazione leggera). Se nel prototipo la bambina
  si blocca, si corregge l'icona, non si aggiungono spiegazioni.

## 5. Storie utente

Le decisioni F-01…F-15 descrivono già il comportamento atteso; le storie
utente con criteri di accettazione verranno scritte come issue GitHub, una per
funzionalità, quando si avvia lo sviluppo della v1.

## 6. Priorità (F-16) ✅

**v1:** galleria con "+", foglio bianco subito, editor a tre zone con opzione
mancina/o, blocco rotazione · matita, pennarello, pennello, pastello a cera,
arcobaleno, gomma · 12 colori + 40, 4 spessori per strumento, annulla/ripeti
salvati · scritte con 4 caratteri · galleria con duplica/salva/stampa/
condividi/elimina, cestino 30 giorni · 6 sfondi, ~150–200 adesivi Fluent Emoji,
7 forme, lazo con duplica · pagina genitori · suoni e vibrazione · italiano e
inglese · GitHub Releases e Google Play.

**Dopo la v1, in ordine:**
1. Altri pennelli magici ed evidenziatore (scelti dalla bambina) → v1.1, F-17
2. Secchiello e disegni da colorare (D-06) → v1.1, F-18 e F-19
3. Sfondi illustrati e adesivi disegnati da noi
4. Backup ed esportazione/importazione `.zip`
5. Zoom, se il prototipo lo richiede (D-07)
6. Contagocce (F-05)
7. Supporto penna (AD-07)
8. "Trasforma in disegno" (AD-05)
9. Catalogo online e importazione pacchetti (AD-17)
10. F-Droid (AD-15)

## 7. Versione 1.1

Punti 1 e 2 della lista "dopo la v1": pennelli magici ed evidenziatore,
secchiello e disegni da colorare. Pennelli magici proposti alla bambina:
glitter, neon, stelline, spray e acquerello.

#### F-17 — Pennelli magici ed evidenziatore

- **Stato:** ✅ approvata (2026-10-27)
- I pennelli magici stanno nella categoria **"✨ Magia"** (F-20), insieme
  all'arcobaleno.

| Pennello | Tratto | Colore |
|---|---|---|
| 🖍️ Evidenziatore | Largo, semitrasparente, punta piatta; ripassando nello stesso tratto non si scurisce | Selezionato |
| ✨ Glitter | Brillantini sparsi lungo il tratto, di grandezze e luminosità diverse | Sfumature del selezionato |
| 💡 Neon | Linea chiara al centro con un alone luminoso del colore scelto; bellissimo su carta scura | Selezionato |
| ⭐ Stelline | Una scia di stelline (o cuori) a distanza regolare, grandi quanto lo spessore | Selezionato |
| 🎨 Spray | Bomboletta: nuvola di puntini, più fitta al centro | Selezionato |
| 💧 Acquerello | Colore morbido e trasparente con bordi sfumati; ripassando si scurisce | Selezionato |

- Valgono le regole degli altri strumenti: **4 spessori** ricordati per
  pennello, la **gomma** cancella anche i tratti magici, si spostano con il
  lazo, si annullano.
- Gli effetti "casuali" (glitter, spray) usano un **seme salvato nel
  tratto**: riaprendo il disegno i brillantini sono esattamente dove erano.
- I disegni con i nuovi pennelli non si aprono con la v1.0 (versione del
  formato più alta): l'app mostra il messaggio già previsto.

#### F-18 — Secchiello

- **Stato:** ✅ approvata (2026-10-27)
- Strumento **🪣 Secchiello**: un tocco riempie del colore selezionato la zona
  chiusa sotto il dito.
- **Bordi:** tratti e forme. Righe e quadretti del foglio, scritte e adesivi
  non fermano il colore.
- **Buchi piccoli** nel contorno (fino a circa lo spessore "medio") vengono
  chiusi, così il colore non "scappa" per un tratto non perfettamente chiuso.
- Il riempimento sta **sotto i tratti**: le linee restano sempre nette sopra
  il colore. Un riempimento nuovo sta sopra quelli vecchi.
- Toccando una zona aperta si colora tutto lo spazio libero del foglio
  (annullabile).
- Il riempimento è un elemento come gli altri (`FillElement`, AD-04): si
  annulla, la gomma lo cancella, il lazo lo sposta.

#### F-19 — Disegni da colorare

- **Stato:** ✅ approvata (2026-10-27)
- Nella galleria, accanto al "+", un secondo pulsante **"📖 Da colorare"**
  apre una griglia di disegni; un tocco crea un foglio nuovo con quel disegno.
- Il contorno è **sopra** tratti e riempimenti (colorando fuori dalle linee
  le linee restano visibili) e **sotto** scritte e adesivi. Non si cancella
  e non si sposta; il secchiello lo usa come bordo.
- Il contorno si adatta al foglio con un margine, in verticale o in
  orizzontale come il tablet.
- I disegni arrivano come **pacchetto di contenuti** (`coloring/*.svg`,
  AD-17). Prima dotazione: **circa 20 disegni** (animali, veicoli, natura,
  feste), **disegnati da noi** in SVG con contorni semplici e spessi, rilasciati
  CC0 (D-12).

#### F-20 — Strumenti a categorie

- **Stato:** ✅ approvata (2026-10-30), aggiorna F-03
- Con pennelli magici e secchiello gli strumenti diventerebbero 17: non
  stanno più nelle due colonne di oggi. Si raggruppano in **8 categorie**,
  in **una colonna** (orizzontale) o **una riga** (verticale):

| Categoria | Strumenti |
|---|---|
| ✏️ Disegna | Matita, pennarello, pennello, pastello a cera |
| ✨ Magia | Arcobaleno, evidenziatore, glitter, neon, stelline, spray, acquerello |
| 🧽 Gomma · 🪣 Secchiello · 🔤 Testo · 😀 Adesivi · ⬛ Forme · ⬚ Seleziona | Uno ciascuna, come oggi |

- Ogni pulsante mostra l'**ultimo strumento usato** della categoria, ricordato
  tra una sessione e l'altra: **un tocco** lo seleziona subito.
- Nelle categorie con più strumenti (segnate da un **triangolino**
  nell'angolo) lo stesso tocco apre un **pannellino** accanto con gli altri
  strumenti. Toccare di nuovo la categoria lo chiude.
- Il pannellino **si chiude da solo** scegliendo uno strumento o toccando il
  foglio; il tocco sul foglio **disegna già**, non va sprecato.
- **Tenendo premuto** una categoria si apre il pannellino senza cambiare
  strumento.
- **Colori invariati** (F-05): i 12 colori restano sempre visibili, perché si
  cambiano molto più spesso degli strumenti.
- **Spessori:** in orizzontale restano i 4 pallini; in **verticale** diventano
  **un pulsante** che mostra lo spessore attuale e apre un pannellino con i
  4, che si chiude da solo come quello degli strumenti. Così colori e
  spessore stanno in una riga senza scorrere.
- Scelta fra tre proposte (A, B, C) con i mockup in
  [`risorse/design/layout-strumenti.html`](risorse/design/layout-strumenti.html):
  scelta la A. Scartate la B (strumenti della categoria sempre visibili: foglio
  più piccolo) e la C (anche i colori a famiglie: cambiare colore costerebbe
  due tocchi).

### Decisioni della v1.1

| Codice | Domanda | Decisione |
|---|---|---|
| D-11 | Spray o acquerello? | ✅ **Deciso:** entrambi |
| D-12 | Da dove prendiamo i disegni da colorare? | ✅ **Deciso:** disegnati da noi in SVG, CC0, rivisti dai genitori e dalla bambina |
