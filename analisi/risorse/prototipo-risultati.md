# Prototipo tecnico — risultati

- **Ramo:** `prototype`
- **Codice:** motore in `packages/pastello_engine` (si tiene), app di prova in
  `prototype/` (si butta)
- **Ultimo aggiornamento:** 2026-10-24

## Cosa c'è nel prototipo

- Strumenti: matita, pennarello, pennello (spessore dalla velocità), pastello
  a cera (grana della carta), arcobaleno, gomma legata ai tratti (AD-05).
- 12 colori (G-02), 4 spessori ricordati per strumento (F-06), annulla /
  ripeti / pulisci (AD-06), blocco rotazione (AD-01).
- Immagine pronta (cache raster) con aggiornamento incrementale (AD-04),
  attivabile/disattivabile per il confronto.
- Pannello misure e generatore di 100/500 tratti casuali.

## 1. Prove nel browser (Chromium headless, rendering software)

> I numeri del browser **non** valgono per le prestazioni sul tablet (AD-04):
> servono solo a confrontare le varianti tra loro.

| Prova | Risultato |
|---|---|
| Disegno con 502 tratti / 37.085 punti, **cache attiva** | 60 FPS, frame peggiore 16,8 ms, aggiornamento incrementale della cache 10,6 ms |
| Ricostruzione completa della cache con 500 tratti (annulla, ripeti, pulisci) | 686 ms |
| Stesso disegno, **cache disattivata** | la prova (un tratto disegnato senza cache) non era ancora finita dopo 2 minuti: la cache è indispensabile |

Osservazioni visive:

- Pastello a cera: la grana della carta rende bene l'effetto cera, da
  rivedere a schermo reale.
- Arcobaleno: sfumatura continua (disegnato a "impronte" raggruppate per
  colore); leggero bordo a perline sui tratti molto spessi.
- Pennello: lo spessore cambia con la velocità come previsto.
- Gomma: cancella tutti i tratti attraversati senza toccare il foglio.

## 2. Prove sul Redmi Pad 2 (modalità profile)

Dispositivo: Redmi Pad 2 (`2505DRP06E`), Android 16, 8 GB RAM, SoC MT8781,
2560×1600 a 90 Hz (budget per frame: **11,1 ms**), Impeller su Vulkan.
Tratti simulati con `adb shell input swipe` (tratti lunghi ~1700 px in 0,8 s).
Misure da `FrameTiming`: per ogni finestra di ~10 frame si registra il tempo
di raster peggiore.

| Prova | Risultato |
|---|---|
| Aggiunta di un tratto alla cache (incrementale) | **0,2–0,3 ms** con 5 o 514 tratti |
| Ricostruzione completa della cache, 500 tratti (+500) | **48 ms** |
| Annulla con 514 tratti (ricostruzione) | **38–45 ms** (sotto la soglia di 100 ms: gli snapshot non servono per ora) |
| Pennarello, 10 tratti lunghi su 510 tratti | raster peggiore medio 7,5 ms; 22 finestre su 82 con almeno un frame oltre 11,1 ms (picco 17 ms) |
| Pastello, 10 tratti lunghi su 520 tratti | raster peggiore medio 9,7 ms; 28 finestre su 88 oltre budget (picco 17 ms) |
| Pastello, 10 tratti lunghi su foglio vuoto | raster peggiore medio 9,6 ms; 20 finestre su 83 oltre budget (picco 17,5 ms) |

Conclusioni:

- ✅ **La cache funziona**: il numero di tratti già disegnati non influisce
  sulla fluidità (foglio vuoto ≈ 520 tratti).
- ✅ **Annulla** è abbastanza veloce anche con 500 tratti (~40 ms).
- ⚠️ **Il costo viene dal tratto in corso**: ogni frame ridisegna l'intero
  tratto che si sta tracciando (e, per il pastello, la sua grana). Con tratti
  lunghi si sfora a tratti il budget di 90 Hz (picchi di 17 ms ≈ un frame
  saltato ogni tanto).
- **Ottimizzazione da fare:** "congelare" la parte già tracciata del tratto in
  corso in un'immagine e ridisegnare dal vivo solo l'ultimo pezzo (estensione
  dell'ottimizzazione 1 di AD-04). Il costo per frame diventerebbe costante
  anche per tratti lunghissimi.

Da verificare a mano:

- [ ] ritardo percepito del tratto sotto il dito;
- [ ] taratura dei 4 spessori (F-06);
- [ ] aspetto di pastello a cera e arcobaleno a schermo reale;
- [ ] palmo appoggiato mentre si disegna.

## 3. Prova con la bambina

_Da fare._ Da osservare:

- [ ] riconosce gli strumenti dalle icone?
- [ ] appoggia il palmo o un secondo dito mentre disegna?
- [ ] cerca di ingrandire il foglio con due dita? (D-07)
- [ ] cosa le piace di più / cosa cerca e non trova.
