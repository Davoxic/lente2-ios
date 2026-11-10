# Lente 2

Client iOS minimalista progettato per l'uso consapevole dei contenuti: ricerca mirata di profili, visualizzazione di immagini e video in alta definizione, download locale e ricondivisione (regram) con attribuzione all'autore originale.

Niente feed algoritmici, niente Reel, niente raccomandazioni studiate per il doomscrolling.

---

## Caratteristiche

- **Ricerca Diretta**: cerca qualunque account digitando lo username o il nome, senza passare da un feed esplora.
- **Visualizzazione Pulita**: griglia dei post del profilo selezionato, supporto per immagini singole, caroselli a scorrimento e video con controlli audio.
- **Regram Studio**: genera una copia del post con badge di attribuzione trasparente all'autore originale (`⟲ @username`), posizionabile a scelta (in basso a sinistra, a destra o disattivato).
- **Download Media**: salvataggio diretto di foto e video nella galleria Foto di iOS tramite il framework Photos.
- **Copia Rapida**: pulsanti per copiare la didascalia originale o il link diretto al post.
- **Sessione Webkit**: gestione dell'accesso tramite interfaccia WebKit protetta su dispositivo.

---

## Compilazione automatica dell'IPA (GitHub Actions)

Il repository include una GitHub Action (`.github/workflows/build-ipa.yml`) che compila automaticamente l'app su un runner macOS e genera un pacchetto `.ipa` non firmato:

1. A ogni push su `main` o al lancio manuale da **Actions**, la pipeline:
   - Configura XcodeGen ed esporta il progetto `Lente.xcodeproj` a partire da `project.yml`.
   - Compila l'applicazione con `xcodebuild` in modalità Release senza firma forzata (`CODE_SIGNING_ALLOWED=NO`).
   - Impacchetta il binario compilato all'interno di una cartella `Payload` generando `Lente2-unsigned.ipa`.
2. L'IPA è scaricabile direttamente dagli **Artifacts** della run.
3. Se viene inserito un tag di versione (es. `v1.0.0`), la pipeline crea una Release GitHub allegando il file `.ipa`.

---

## Installazione (Sideloading)

Poiché l'IPA prodotto dalla pipeline non è firmato, può essere installato e firmato tramite:

- **AltStore / SideStore**: importando direttamente il file `.ipa` o inserendo l'URL della Release.
- **TrollStore**: installazione diretta senza necessità di rinnovo per versioni iOS compatibili.
- **Sideloadly**: collegando l'iPhone al computer e trascinando l'IPA.
- **Xcode**: aprendo il file `.xcodeproj` generato localmente con `xcodegen generate` e selezionando il proprio account di sviluppo.

---

## Struttura del progetto

```
project.yml                     Specifica XcodeGen per generare Lente.xcodeproj
Support/Info.plist              Dichiarazioni permessi (Galleria Foto, Schemi URL)
Resources/Assets.xcassets       Icona applicazione e colori
Sources/
  App/                          Entry point (LenteApp, AppState)
  Models/                       Strutture dati (User, Post, MediaItem)
  Services/                     SessionManager, InstagramAPI, RegramService
  UI/                           Interfacce SwiftUI (Search, Profile, Post, Regram, Settings)
.github/workflows/build-ipa.yml Pipeline di compilazione e rilascio
```

---

## Licenza

Distribuito sotto licenza MIT.
