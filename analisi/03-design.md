# 03 — Design e grafica

- **Stato:** ✅ approvato (2026-10-24)
- **Presentazione:** [`risorse/design/proposta-design.html`](risorse/design/proposta-design.html)
  (anche in [PDF](risorse/design/proposta-design.pdf))
- **Versione inglese per i contributori:** [`../docs/design/README.md`](../docs/design/README.md)

Direzione: **"carta e pastelli"**. L'interfaccia è un tavolo da disegno caldo e
tranquillo; i colori forti stanno nel disegno, non nei pulsanti.

Principi: il disegno è la star · grande e tondo · icone, non parole · stato
evidente · giocoso, non chiassoso.

## G-01 — Palette dell'interfaccia ✅

| Nome | Colore | Uso |
|---|---|---|
| Carta | `#FFF8EE` | Sfondo dell'app |
| Foglio | `#FFFFFF` | Area di disegno |
| Inchiostro | `#2D2A32` | Testo, contorni delle icone |
| Grafite | `#6B6672` | Testo secondario |
| Bordo | `#EADFCF` | Separatori |
| **Corallo** | `#E8553A` | Primario: "+", strumento attivo |
| Sole | `#FFC53D` | Accento, interruttori accesi |
| Cielo | `#2C7BE5` | Selezione, maniglie |
| Menta | `#1E9E85` | Conferma |
| Lampone | `#D93D42` | Elimina |

Solo **tema chiaro** nella v1.

## G-02 — Colori per disegnare ✅

12 fissi (F-05): rosso `#E63946` · arancione `#FF8C42` · giallo `#FFD23F` ·
verde chiaro `#8BD346` · verde scuro `#2A9D3F` · azzurro `#4CC9F0` ·
blu `#1D4ED8` · viola `#8E44AD` · rosa `#FF7EB6` · marrone `#8B5A2B` ·
nero `#1F1F1F` · bianco `#FFFFFF`.

Griglia "altri colori": 40 colori in 4 righe (toni della pelle, pastello,
scuri, grigi e vivaci), valori nella presentazione (slide 4).

## G-03 — Caratteri dell'interfaccia ✅

- **Fredoka** per titoli e pulsanti, **Andika** per i testi.
- Sono già inclusi per le scritte (F-08): nessun peso aggiuntivo.

## G-04 — Icona dell'app ✅

- **Proposta C: pastello con la faccina**, su cielo azzurro con sole e prato.
- Diventa anche la **mascotte** dell'app (galleria vuota, cancello genitori,
  messaggi).
- Da realizzare come *adaptive icon* Android (primo piano + sfondo, soggetto
  nella zona sicura) e icona monocromatica per i temi a tema di Android.

## G-05 — Icone ✅

- **Strumenti:** piccoli disegni colorati con contorno Inchiostro; la **punta
  prende il colore selezionato**.
- **Azioni:** tratto spesso e arrotondato.
- Tutte **disegnate da noi in SVG**, nessuna libreria di icone.

## G-06 — Editor ✅

Come nel mockup (slide 8): strumento attivo con fondo Corallo chiaro e
cornice Corallo spessa; colore attivo con doppio anello; spessori come pallini
nel colore selezionato.

## G-07 — Galleria e cancello genitori ✅

Come nel mockup (slide 9): "+" Corallo che "respira", miniature con pulsante
⋯, cancello con tastierino numerico grande e tasto ✓ Menta.

## G-08 — Movimento, suoni, accessibilità ✅

- Animazioni brevi (150–300 ms), mai bloccanti; rispetto di "riduci
  animazioni" di Android.
- Contrasti: Inchiostro su Carta 13,4:1, Grafite su Carta 5,3:1 (WCAG AA);
  bianco su Corallo 3,6:1 solo per icone e testo grande (≥ 24 px).
- Target touch ≥ 56 dp (strumenti 64 dp); lo stato attivo non è mai
  segnalato solo dal colore; ogni pulsante ha un'etichetta per i lettori di
  schermo.
