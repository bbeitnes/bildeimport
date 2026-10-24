# Bildeimport

En enkel Mac-app som henter bilder og videoer fra et minnekort og legger dem i mapper etter år og dato:

```text
Bilder/
    2025/
        2025-12-31/
    2026/
        2026-10-24/
    Ukjent dato/
```

Sett inn kortet, trykk **Importer**, og trykk **Løs ut minnekortet** når appen er ferdig. Bildene blir også liggende på kortet.

## Last ned og installer

1. Gå til **Releases** i dette repositoriet og last ned den nyeste `Bildeimport-x.y.z.dmg`.
2. Dobbeltklikk på DMG-filen. Dra **Bildeimport** over på **Programmer**.
3. Åpne **Bildeimport** fra Programmer-mappen eller Launchpad.

### Første gang appen åpnes

Appen er ikke godkjent av Apple, fordi den ikke er signert med et betalt utviklermedlemskap. macOS stopper den derfor første gang. Dette må bare gjøres én gang:

1. Når meldingen om at appen ikke kunne åpnes vises, trykker du **Ferdig**.
2. Åpne **Systeminnstillinger** og velg **Personvern og sikkerhet**.
3. Bla ned til meldingen om Bildeimport, og trykk **Åpne likevel**.
4. Skriv inn passordet til Macen, og trykk **Åpne** én gang til.

Første gang et minnekort settes inn, spør macOS om Bildeimport får tilgang til filer på en flyttbar enhet. Trykk **Tillat**.

Etter dette åpnes appen som en vanlig app.

## Slik fungerer appen

- **Kortet** oppdages automatisk. En flyttbar disk regnes som minnekort når den har en kameramappe som `DCIM` eller Sonys `PRIVATE/M4ROOT`. Med flere kort satt inn velger brukeren kort fra en liste.
- **Hovedmappen** huskes til neste gang. Standardvalget er brukerens Bilder-mappe. Hvis mappen ligger på en ekstern disk som ikke er koblet til, sier appen fra.
- **Datoen** hentes fra opptaksdatoen i filen. For bilder brukes EXIF-datoen slik kameraet skrev den. For Sony-video brukes XML-filen kameraet lager ved siden av klippet, og for annen video regnes tiden om til Macens tidssone. Mangler opptaksdato, brukes filens endringsdato. Mangler også den, havner filen i `Ukjent dato`.
- **Ingenting overskrives.** En identisk fil som allerede er importert, hoppes over. En annen fil med samme navn får et nummer, for eksempel `IMG_1234 (2).JPG`.
- **Hver kopi kontrolleres** byte for byte mot originalen før den får sitt endelige navn.
- Bare bilder og videoer kopieres, også RAW-filer fra Olympus (ORF), Canon (CR2, CR3, CRW) og Sony (ARW, SR2, SRF). Hjelpefiler som `.THM`, `.XML` og `.XMP` hoppes over.

## For utviklere

Krav: macOS 15 eller nyere på Apple Silicon, og Xcode 16 eller nyere.

```bash
swift test                     # kjør testene
swift run Bildeimport          # start appen fra Terminal
scripts/build-dmg.sh 1.0.0     # bygg build/Bildeimport-1.0.0.dmg
```

Du kan også åpne `Package.swift` i Xcode.

### Ny versjon

Lag en tagg og push den. GitHub Actions bygger da DMG-filen og legger den ut under Releases:

```bash
git tag v1.0.0
git push origin v1.0.0
```

### Oppbygging

| Mappe | Innhold |
| --- | --- |
| `Sources/ImportCore` | All importlogikk uten brukergrensesnitt: kortgjenkjenning, søk etter filer, datoer, mappestruktur, duplikater og kopiering |
| `Sources/Bildeimport` | SwiftUI-appen: vinduet, skjermbildene og overvåking av kort |
| `Tests/ImportCoreTests` | Enhetstester for importlogikken |
| `Resources` | `Info.plist` og app-ikonet |
| `scripts/build-dmg.sh` | Bygger appen og DMG-filen |
| `docs/spesifikasjon.md` | Alle beslutninger om hvordan appen skal fungere |
