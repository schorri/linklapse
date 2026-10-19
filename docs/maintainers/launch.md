# GitHub-Start für schorri/linklapse

Das Quellprojekt und die Release-Dateien sind lokal vorbereitet. Ein öffentlicher Upload ist ein separater Schritt.

## Repository

Unter dem Konto **schorri** ein leeres öffentliches Repository **linklapse** anlegen. README und Lizenz sind bereits enthalten; bei der Repository-Erstellung keine zusätzlichen generieren lassen.

Beschreibung:

> Free Wi-Fi & Internet stability monitor for Windows. Track dropouts, latency and packet loss, compare network paths, and export local reports. Portable, no account required.

Topics:

`wifi`, `internet-monitoring`, `network-monitoring`, `windows`, `powershell`, `network-diagnostics`, `packet-loss`, `latency`, `troubleshooting`, `speedtest`, `portable`, `open-source`

Diese Werte liegen auch in `.github/repository.json`. Die Datei dokumentiert die Einstellungen; GitHub übernimmt sie nicht automatisch.

## Inhalt hochladen

Das **LinkLapse-GitHub-v0.1.0.zip** entpacken und den Inhalt des inneren LinkLapse-Ordners hochladen, nicht den äußeren Ordner als zusätzliche Verzeichnisebene. `README.md`, `src`, `web`, `.github` usw. müssen im Repository-Stamm liegen. `data`, `reports`, private Screenshots und Laufprotokolle gehören nicht hinein.

Alternativ das vorbereitete lokale Git-Projekt mit GitHub Desktop öffnen und den ersten Commit mit der eigenen Identität erstellen. Der vorgesehene Remote ist `https://github.com/schorri/linklapse.git`. Es wurde kein Autorname oder keine E-Mail-Adresse für einen Commit erfunden.

Der Workflow **Checks** baut den Starter und führt die Offline-Tests aus. Ergebnisse prüfen, bevor ein Release beworben wird. Unter Security bei Bedarf Private Vulnerability Reporting aktivieren. Unnötige Wiki-/Projektbereiche können deaktiviert werden.

## Release

Ein Release **LinkLapse v0.1.0** zum Tag **v0.1.0** zunächst als Entwurf anlegen. Der Text steht unter `docs/releases/v0.1.0.md`. Anhängen:

- `LinkLapse-Windows-v0.1.0.zip`
- `LinkLapse-GitHub-v0.1.0.zip`
- `SHA256SUMS.txt`

Die Prüfsummendatei enthält beide ZIP-Dateien. Das Quellpaket enthält keinen vorgebauten Starter, der Windows-Download enthält ihn. Für den ersten öffentlichen Test **This is a pre-release** auswählen.

Alternativ unter **Actions → Prepare release draft → Run workflow** den Branch `main` und den Tag `v0.1.0` auswählen. Der Workflow erstellt nach Tests und Paketbau einen Vorabversions-Entwurf mit beiden ZIP-Dateien und der dazugehörigen Prüfsummenliste. Er veröffentlicht ihn nicht automatisch. Unter **Releases** den Entwurf öffnen, den dort angehängten Windows-Download auf dem privaten Laptop entpacken und starten. Danach mit **Publish release** veröffentlichen. Die automatisch von GitHub angebotenen Source-code-Archive enthalten keinen vorgebauten Windows-Starter.

## Vorschau und Auffindbarkeit

Unter Repository Settings → Social preview **docs/assets/social-preview.png** hochladen. Die README zeigt bereits **docs/assets/dashboard.png**. Beide Bilder und `docs/assets/demo.html` enthalten ausschließlich synthetische Daten. Das Projekt kann im Profil angeheftet werden.

Der erste Eindruck soll drei Fragen beantworten: Was hilft es mir? Wie sieht es aus? Wie starte ich es? Deshalb stehen Nutzen, Screenshot und Download vor den technischen Details. Die englische README ist der Einstieg, Deutsch bleibt direkt erreichbar. Beschreibung und Topics nennen die tatsächlichen Funktionen, keine erfundenen Optimierungs- oder Reparaturfähigkeiten.

Nach einem längeren privaten Praxistest einen kurzen Erfahrungsbeitrag mit einem bereinigten echten Zeitfenster vorbereiten: welches Symptom auftrat, was gemessen wurde, was offenblieb. In passenden Windows-/Heimnetzwerk-Communities nur dort teilen, wo Projektvorstellungen erlaubt sind. Fragen beantworten und konkrete Rückmeldungen in kleine Verbesserungen umsetzen. Keine Massenposts, gekauften Sterne oder erfundenen Nutzerzahlen.

Möglicher englischer Vorstellungstext:

> I built LinkLapse to make intermittent Wi-Fi and Internet problems easier to document. It runs from a portable Windows ZIP, starts from a local dashboard, and puts signal quality, gateway checks and external tests on one timeline. Logs stay local, and reports export as HTML/CSV/ZIP. It is free and MIT licensed. This first release needs more long-run feedback from real home networks. Source and download: https://github.com/schorri/linklapse

## Spätere Versionen

Version in Launcher, Host, Paketierung und Release-Notizen gemeinsam ändern. `tools/Build.ps1` und die Tests ausführen, danach `tools/Package.ps1`. Screenshot nur bei sichtbaren Änderungen erneuern. Verbesserungen und verbleibende Grenzen knapp in den Release-Notizen nennen.

Grundlagen: [GitHub Topics](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics), [Social preview](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview).
