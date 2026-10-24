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

_Da fare._ Da misurare:

- [ ] fluidità a 90 Hz con 0, 100, 500 tratti (build + raster < 11 ms);
- [ ] tempo di ricostruzione della cache con 500 tratti (annulla):
      se > 100 ms servono gli snapshot (AD-04, ottimizzazione 4);
- [ ] ritardo percepito del tratto sotto il dito;
- [ ] taratura dei 4 spessori (F-06);
- [ ] aspetto di pastello a cera e arcobaleno a schermo reale.

## 3. Prova con la bambina

_Da fare._ Da osservare:

- [ ] riconosce gli strumenti dalle icone?
- [ ] appoggia il palmo o un secondo dito mentre disegna?
- [ ] cerca di ingrandire il foglio con due dita? (D-07)
- [ ] cosa le piace di più / cosa cerca e non trova.
