# LinkLapse verwenden

## Öffnen und starten

Das Release-ZIP vollständig in einen neuen, beschreibbaren lokalen Ordner entpacken. Keine Dateien über eine laufende ältere Installation kopieren. Alte Messordner behalten.

**LinkLapse.exe** öffnet das Dashboard im Standardbrowser. Es erscheint kein zu bedienendes Konsolenfenster. **START.cmd** öffnet denselben Starter. Ein erneuter Doppelklick bringt dich zur bereits laufenden Oberfläche desselben Ordners zurück.

Den Laptop mit dem betroffenen Netz verbinden, ans Netzteil anschließen und geöffnet lassen. Für einen reinen WLAN-Vergleich VPN und Ethernet nach Möglichkeit deaktivieren. Werden sie gebraucht, lassen sich die unterschiedlichen Routen trotzdem getrennt betrachten.

Im Dashboard:

1. **Messdauer** auswählen: 5 Minuten, 1 Stunde, 24 Stunden, 3/7/14/30 Tage oder bis zum Stoppen.
2. Bei Bedarf **Download-Proben** einschalten und deren Last begrenzen.
3. **Messung starten** anklicken. Nach den ersten Proben erscheinen die Bereichskarten und Diagramme.

Die Auswahl bleibt während einer Messung gesperrt. Änderungen gelten für die nächste Sitzung: erst stoppen, dann neu auswählen. Mit **Stoppen** endet die Messung regulär. Begonnene Web-/Download-/Pfadtests werden innerhalb ihrer Zeitlimits abgeschlossen; der Status kann deshalb noch einige Sekunden „wird beendet“ anzeigen.

Eine zeitlich begrenzte Messung endet selbst. **Beenden** oben in der Steuerung stoppt die Messung und schließt anschließend die Hintergrundanwendung. Das Schließen des Browser-Tabs allein stoppt sie nicht. Zum Zurückkehren LinkLapse.exe erneut öffnen.

Die Oberfläche wird nur über die lokale Adresse dieses Computers bereitgestellt. Es ist kein Cloud-Dashboard. Deutsch/English lässt sich oben jederzeit wechseln. Die Messdaten erscheinen ungefähr alle fünf Sekunden neu; während ein Messbelegdialog offen ist, bleibt dessen Ansicht stehen.

## Was gemessen wird

| Bereich | Standard |
| --- | --- |
| Adapterstatus und WLAN-Signal | Jede Sekunde |
| Gateway und drei externe Pings | Parallel jede Sekunde, 800 ms Timeout |
| Zwei TCP-Dienste | Alle fünf Sekunden |
| Zwei kleine HTTPS-Prüfungen | Alle 60 Sekunden |
| Begrenzte Pfaderkennung | Beim Start, bei Routenwechsel und alle 15 Minuten |
| Gateway, sichtbare Router-Hops, optional AP-Verwaltung | Alle fünf Sekunden; bis zu drei zusätzliche Hops je Pfad |
| Download-Proben | Optional; erstmals nach einer Minute, dann standardmäßig stündlich |

WLAN-Prozentwerte sind die von Windows gemeldete Signalqualität, keine exakten dBm. WLAN-Linkraten sind keine Internetgeschwindigkeit. Fehlende Werte bleiben unbekannt. Sehr kurze Aussetzer können zwischen zwei Proben liegen; Timeout und Messintervall begrenzen die Auflösung.

## Dashboard lesen

Die Gesamteinordnung und vier Karten beziehen sich auf den letzten Messstand: WLAN bzw. Netzwerkadapter, AP, Gateway/Router und Internet. Erfolgreiche Einzeltests bestätigen nicht sämtliche Dienste. Knoten in der Pfadübersicht lassen sich für die zugehörigen Belege anklicken.

Die **Ansicht** über dem Zeitverlauf bestimmt den sichtbaren Zeitraum von Zeitspuren, Diagrammen und Ereignistabelle. Sie ändert nicht die Messdauer. Eine erst fünf Minuten alte Messung nutzt auch bei gewählten 24 Stunden den vorhandenen Zeitraum. Bereichskarten, letzte Download-Probe und Gesamtstatistiken bleiben als letzter Stand bzw. Sitzungswerte erkennbar.

Oben stehen Messdauer, Download-Schalter und Start/Stopp nebeneinander. Nach dem Einschalten der Download-Proben öffnen sich deren Einstellungen; beim Start werden die Zusatzoptionen eingeklappt. Unter den Diagrammen lassen sich **Netzwerkpfade**, **Auffällige Messabschnitte** und Messdetails einzeln öffnen. Die Navigation oben springt zum Zeitverlauf, den Diagrammen oder den Details. Exportierte Berichte zeigen die ausführlichen Abschnitte von Anfang an.

Antwortzeiten stehen in **ms**, Signalqualität und fehlende Antworten in **%**, Download-Proben in **Mbit/s**. Die Zeitachse verwendet die Ortszeit des Browsers. Das Signal nutzt immer 0–100 %; die übrigen Skalen passen sich den sichtbaren Werten an. Beim Vergleich verschiedener Zeiträume deshalb die Achsen beachten.

Mit der Maus über das Diagramm fahren oder antippen, um Zeitpunkt und Werte zu sehen. Alternativ das Diagramm fokussieren und mit den Pfeiltasten links/rechts blättern; Pos1/Ende springt zum ersten/letzten verfügbaren Punkt, Escape schließt die Anzeige. Die Messwertanzeige nennt die Proben- oder Aggregationsauflösung. Messlücken bleiben offen. Download-Markierungen stehen für einzelne Tests; daraus wird keine durchgängige Geschwindigkeit zwischen den Tests abgeleitet.

Die Grafik wechselt von Einzelproben bis eine Stunde über Minutenwerte bis 24 Stunden und Stundenwerte bis 30 Tage zu Tageswerten. Bei Zusammenfassung werden Latenzmaximum und Signalminimum gezeigt. Der Ping-Fehlanteil nutzt die tatsächlich gewerteten Proben. Die Latenz- und Fehlanteilsskala passt sich an, Signal behält 0–100 %. Messlücken und Routenwechsel werden nicht durch eine durchgehende Linie überbrückt.

Zeitspuren zeigen WLAN bzw. Adapter, Gateway, Internet-Ping, TCP und vorhandene AP-/Router-Knoten getrennt. Rot steht für fehlende Antworten oder Trennung, Orange für Signal/Latenz/Teilantwort, Grau für unklare oder nicht gewertete Bereiche. Ein Klick zeigt Uhrzeiten, Probenzahlen und die **mindestens beobachtete Spanne**.

Eine Einzelprobe belegt 0 Sekunden Spanne. Beginn und Erholung können zwischen Proben liegen oder unbekannt bleiben. Ein roter Abschnitt ist deshalb kein sekundengenauer Nachweis eines vollständigen Internetausfalls. Messpausen sind fehlende Beobachtungen, keine belegten Netzstörungen. Bei beschnittenen Ansichten gehören Zählwerte zum gesamten gespeicherten Abschnitt; Zeitgrenzen werden auf die Ansicht begrenzt.

Die Liveansicht hält bis zu 500 letzte Zustandsabschnitte je Hauptspur, 200 je Zusatzknoten und 200 Messlücken. Die Tabelle zeigt höchstens 200 enthaltene Auffälligkeiten. Ältere nicht enthaltene Bereiche bleiben grau. Rohlogs behalten alle Einzelproben. Jede neue Sitzung beginnt eine neue Liveansicht; der Bericht kann mehrere Sitzungen umfassen.

Unter **Messdetails & Rohstatistik** stehen Lernstatus, Rohfehlversuche und gewertete Ping-Proben getrennt. Mittelwert, P95 und Maximum beziehen sich auf erfolgreiche Antworten. P95 nutzt auf ganze Millisekunden gerundete Werte. Web- und Downloadtabellen enthalten auch gescheiterte Versuche.

## AP, Router und Internet unterscheiden

Ohne manuelle Auswahl nutzt LinkLapse den Adapter der IPv4-Route zum zweiten Ping-Ziel, standardmäßig 8.8.8.8. Unter **Verbindungs- und Energieoptionen** kann ein konkreter Adapter gewählt werden. Ethernet wird ebenfalls unterstützt.

Ziele mit unterschiedlichem Routenadapter oder Next-Hop erscheinen getrennt. Ein begrenzter TTL-Trace zeigt sichtbare Hops eines Beispielziels je Gruppe. Andere Ziele können weiter hinten anders verlaufen. Nicht antwortende Hops werden nicht als kaputte Router ausgegeben. Tunnel, Proxys, IPv6 und Änderungen während einer Probe begrenzen die Zuordnung.

Ein AP als Bridge und gewöhnliche Switches erscheinen normalerweise nicht als Router-Hops. Ein Gerät kann AP, Switch und Router zugleich sein. Ohne bekannte **AP-Verwaltungsadresse** wird kein individueller AP-Zustand behauptet. Eine bestätigte IPv4-Adresse kann in den erweiterten Optionen eingetragen werden. Es gibt keinen Subnetzscan und keine Router-Anmeldung.

Auch die Verwaltungsadresse wird über ihre eigene Windows-Route geprüft. Passt sie nicht zum erkannten Pfad, bleibt der Knoten unklar. Fehlender Verwaltungs-Ping beweist keinen Ausfall der Weiterleitung.

| Muster | Einordnung |
| --- | --- |
| Windows meldet WLAN-Trennung | Lokale Verbindung getrennt; einzelne Hardwareursache offen |
| Niedrige Signalqualität | Hinweis auf den Funkweg |
| Gateway-/AP-Ping fehlt, Internetdienst antwortet | ICMP-/Verwaltungsauffälligkeit, kein bewiesener Totalausfall |
| Gateway und mehrere externe Tests scheitern | Betroffener gemeinsamer Pfad oder Ziele/Filter; genaue Stelle offen |
| Gateway antwortet, mehrere gelernte externe Pings und TCP auf vergleichbaren Routen scheitern | Problem dahinter plausibel; Provider oder Gerät nicht eindeutig bewiesen |

Ping-Ziele werden erst nach mindestens **8 Antworten in 10 gültigen Proben** je Ziel, Sitzung und Route gewertet. Dauerhaft stumme Ziele bleiben sichtbar, erzeugen aber keinen Ping-Alarm. Nach Freigabe bleibt ein späterer Ausfall auswertbar, auch wenn er lange dauert. Ziel-, Pfad- und Sitzungswechsel sowie größere Messlücken starten neu. Eine bereits anfangs bestehende Störung kann dadurch unbewertet bleiben; TCP, HTTPS und Rohdaten bleiben unabhängig vorhanden.

Zusatzknoten lernen bei ihrem eigenen Intervall. Nach Freigabe sind ein bis zwei aufeinanderfolgende Fehlversuche orange, ab drei rot. Das beschreibt die Antworten des Knotens, nicht seine erwiesene Verantwortung.

## Download-Proben

Die Checkbox aktiviert kurze Downloads für die nächste Sitzung. Einstellbar sind Testabstand, Datenvolumen, Leseratenlimit und ein optionaler Vergleichswert. Standard: erste Probe nach einer Minute, dann stündlich bis zu 5 MiB oder 15 Sekunden. Es gilt das zuerst erreichte Limit. Kein Uploadtest.

Ohne Ratenbegrenzung kann ein kurzer Test die Leitung vorübergehend auslasten. Ein Leseratenlimit reduziert diese Last näherungsweise; Puffer können kurze Spitzen verursachen. Eine gedrosselte Probe belegt nicht die volle Anschlusskapazität. Das Dashboard zeigt eine Abschätzung des täglichen Downloadvolumens.

Der Messwert enthält den Verbindungsaufbau. Kleine Transfers können schnelle Anschlüsse deutlich unterschätzen. Nur vollständige erfolgreiche Transfers werden als Downloadwert dargestellt. Teiltransfers bleiben in Logs/Details. Zeitlich überlappende Grundmessungen sind als eigene Downloadlast markiert.

Vergleichswert 0 schaltet die automatische Langsamkeitsbewertung aus. Sonst wird eine frische, erfolgreiche, ungedrosselte Probe unter Vergleichswert × `SlowRatio` (Standard 0,5) vorsichtig hervorgehoben. Das ist kein amtlicher Breitbandtest und kein Nachweis einer Vertragsverletzung.

## Bericht erstellen

Im Steuerbereich den **Berichtszeitraum** wählen und **Bericht erstellen** anklicken. Die Messung darf weiterlaufen; der Export ist eine Momentaufnahme. Lange Zeiträume können mehrere Minuten dauern. Danach **Bericht öffnen** oder **ZIP herunterladen** verwenden.

Der Bericht enthält ein selbstständiges HTML, deutsche/englische Zusammenfassung, Zielstatistik, alle Hauptspur-Abschnitte, priorisierte Beobachtungsmuster, Messpausen, Zusatzknotenproben, Web-/Downloadtests und Sitzungs-/Topologiemetadaten. Die großen `samples-*.csv` werden nicht automatisch beigepackt; Originale behalten und bei Bedarf separat beilegen.

Das HTML funktioniert auch außerhalb der Anwendung und ohne Internet. Unter Drucken/PDF kann es gedruckt werden; vorher gewünschte Details öffnen. Zeiten im HTML entsprechen der Zeitzone des betrachtenden Browsers, Logs und CSV-Dateinamen nutzen UTC.

Die Pfadübersicht verwendet die letzte vor Berichtsende bekannte Aufnahme. Zusatzknotenspuren beziehen sich auf die letzte enthaltene Sitzung; `nodes.csv` enthält alle Sitzungen im Zeitraum. Sitzungsdateien können ergänzend auch spätere Aufnahmen enthalten, diese werden nicht als damalige Topologie ausgegeben. Der gespeicherte Lernstatus bleibt auch bei Berichten erhalten, die mitten in einer Störung beginnen.

Vor Weitergabe IP-Adressen, Adapterbezeichnungen und URLs prüfen. Ergänzen: Laptopstandort, AP-Abstand, bekannter Aufbau, tatsächliche Nutzungssymptome, parallele Last und weitere betroffene Geräte. Ein Vergleich per LAN oder vor/nach Standortänderung kann helfen. Dateien sind veränderbar und keine manipulationssichere Beweissicherung.

## Standby und Windows-Updates

Die Messung fordert temporär Schutz vor automatischem Schlaf an. Die Anforderung wird am Ende freigegeben; der Energiesparplan bleibt unverändert. Netzteil verwenden und Deckel offen lassen. Manuelles Schlafen, Zuklappen, leere Akkus, Systemfehler und erzwungene Vorgaben können trotzdem unterbrechen. Modern Standby kann Anforderungen im Akkubetrieb begrenzen.

Nur falls gewünscht gibt es unter den erweiterten Optionen **Automatische Windows-Updates vorübergehend pausieren**. Die Auswahl erfordert die Windows-Administratorfreigabe und gilt nur für einen privaten Laptop mit unterstützter Pro-/Enterprise-/Education-/IoT-Edition. Auf Home stattdessen die angebotene Windows-Update-Pause verwenden.

Dabei wird auch die automatische Installation von Sicherheitsupdates pausiert. Der Helfer sichert `NoAutoUpdate` und setzt ihn auf 1. Eine geschützte SYSTEM-Aufgabe stellt den vorherigen Wert nach Ende des zugehörigen Prozesses normalerweise innerhalb etwa einer Minute wieder her. Spätere fremde Änderungen werden nicht überschrieben. Nach abruptem Ausschalten ist die Rücksetzung erst nach dem nächsten Windows-Start möglich. Bei einer bereits erkannten Neustartanforderung startet diese Funktion nicht.

Auch damit gibt es keine absolute Neustartgarantie. Bereits laufende Updates, manuelle/erzwungene Neustarts und zentrale Vorgaben bleiben möglich. Nachher Updates nachholen; bei langen Tests Wartungspausen einplanen. Die normale Messung und das bloße Öffnen der Oberfläche ändern keine Update-Richtlinie.

Für eine manuelle Wiederherstellung kann ein Administrator den mitgelieferten Helfer `src\RichtlinieZuruecksetzen.ps1` ausführen. Die geschützte Sicherung liegt aus Kompatibilitätsgründen unter `%ProgramData%\InternetMonitor-Policy-v1`; Aufgabe: `InternetMonitor-UpdatePolicy-Restore-v1`. Sicherungen nicht vor einer nötigen Wiederherstellung entfernen.

## Dateien und Speicher

`data` enthält Grundrunden, Zusatztests, Sitzungen, Topologie und technische Laufprotokolle. `reports` enthält Exporte. Es gibt keine automatische Löschung. Bei Sekundentakt können die CSV-Dateien über 100 MB pro Tag belegen. Tatsächlichen Zuwachs prüfen, genug Platz vorhalten und alte Tagesdateien bei gestoppter Messung außerhalb von `data` archivieren.

CSV verwendet UTF-8 mit BOM, Semikolon und Dezimalpunkt. In Excel über Daten → Aus Text/CSV importieren und Originale nicht überschreiben. `NotTested` bedeutet nicht geplant, `NoGateway` keine Gatewayadresse, `Error:*` einen lokalen/API-Fehler. Rohfehlversuche sind keine pauschale Internet-Ausfallquote.

Keine Passwörter, SSIDs, BSSIDs oder Browserinhalte werden gespeichert. Messanfragen selbst gehen an die konfigurierten Dienste; diese sehen gewöhnliche Verbindungsmetadaten. LinkLapse lädt keine Ergebnisse hoch.

## Wenn etwas nicht funktioniert

- **Starter wird blockiert:** ZIP aus vertrauenswürdiger Quelle vollständig entpacken. Die erste Version ist nicht digital signiert. Vorhandene Firmen-/AppLocker-/WDAC-Vorgaben respektieren. `data\ui-error.log` enthält Startfehler.
- **Browser meldet Verbindung unterbrochen:** LinkLapse.exe erneut öffnen. Die Hintergrundanwendung kann beendet worden sein. Mess- und Laufprotokolle bleiben in `data`.
- **Messung startet nicht:** Fehlermeldung im Dashboard lesen. Unter `data` liegen Worker-Fehlerprotokolle. Einen beschreibbaren lokalen Ordner und den richtigen Adapter verwenden.
- **Signal fehlt:** WLAN-Treiber und Windows-Datenschutz-/Standortfreigaben prüfen. Ein Administratorstart behebt das nicht allgemein. Andere Messungen können weiterlaufen.
- **AP bleibt unklar:** Ohne bestätigte Verwaltungsadresse ist das erwartbar. AP und Gateway nicht gleichsetzen.
- **Einzelnes Ping-Ziel ist immer stumm:** Mit anderen Zielen und TCP/HTTPS vergleichen. Kein Routerdefekt allein aus ICMP ableiten.
- **Nur HTTPS/Download scheitert:** Ziel, Proxy, TLS, Namensauflösung und Filter prüfen. Der Download verwendet keinen HTTP-Systemproxy.
- **Keine Berichtsdaten:** Zeitraum und enthaltene Sitzungen prüfen. Noch laufende erste Proben abwarten.
- **CSV-Spalten passen nicht:** Eine neue Version in einen neuen Ordner entpacken; alte Rohlogs nicht mit anderen Spalten vermischen.

Weitere Konfiguration, etwa eigene Testziele und Messintervalle, steht in `config.json`. Änderungen daran werden beim nächsten Anwendungsstart gelesen. [Technische Einstellungen](configuration.md) und [Messmethode mit Quellen](measurement-method.md) beschreiben die Details.
