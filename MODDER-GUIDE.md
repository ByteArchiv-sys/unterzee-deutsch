# Übersetzungen prüfen und weiterentwickeln

Die Mod besteht aus zwei technisch getrennten Teilen: dem JSON-Addon und
optionalen Änderungen fester Programmtexte. Für Korrekturen an Geschichten
oder eine weitere Sprache empfiehlt sich zunächst das Addon.

## Dateien und Zuordnung

| Bereich | Addon-Dateien |
| --- | --- |
| Geschichten, Entscheidungen und Ausgänge | `entities/events.json` |
| Gegenstände, Statuswerte, Journal und Tooltips | `entities/qualities.json` |
| Häfen und Gebiete | `entities/areas.json` |
| Märkte und Geschäfte | `entities/exchanges.json` |
| Persona-Beschreibungen | `entities/personas.json` |
| Tutorials | `encyclopaedia/Tutorials.json` |
| Kampfgegenstände und sichtbare Aktionstexte | `encyclopaedia/CombatItems.json`, `encyclopaedia/CombatAttacks.json` |
| Gegner- und Weltobjektanzeigen | `encyclopaedia/SpawnedEntities.json` |
| Kartenbeschriftungen | `geography/Tiles.json` |

Der Mod-Ordner liegt im ZIP unter `package/addon/Unterzee-Deutsch-Start`.
Die fertigen Dateien lassen sich zur Untersuchung mit einem UTF-8-fähigen
Texteditor öffnen. Sie enthalten neben Text auch notwendige Spielstrukturen.
Ein geändertes Installationspaket benötigt neu berechnete Prüfsummen; die
Prüfung des Installers darf dafür nicht abgeschaltet werden.

Eine Textstelle wird durch Datei, Wurzel, Objekttyp, Objekt-ID und Feldpfad
bestimmt. Eine ID allein genügt nicht, weil Referenzobjekte und Unterobjekte
dieselbe ID verwenden können. Bei Karten dienen Gruppen- und Kachelnamen
als Zuordnung; Arraypositionen sind keine dauerhafte Identität.

## Sprache und Gegenlesen

Die deutsche Fassung verwendet gut lesbare, leicht altertümliche Sprache,
eine britisch-gotische Atmosphäre und beiläufigen schwarzen Humor. Die
Erzählstimme spricht die Spielfigur mit „du“ an. Anrede und Ausdruck einzelner
Figuren sollen ihren jeweiligen Charakter erhalten.

Zusammenhängende Geschichten einschließlich Fehlschlägen und seltenen
Ausgängen gemeinsam lesen. Begriffe in Geschichte, Inventar, Journal,
Karte und Tooltip müssen zusammenpassen. Für kurze Titel auch die verfügbare
Breite im Spiel prüfen.

Für eine andere Sprache ist Deutsch eine hilfreiche zusätzliche Referenz.
Der englische Text aus der eigenen Spielinstallation bleibt wichtig, um
Mehrdeutigkeiten, Wortspiele und mögliche Fehler der deutschen Fassung zu
erkennen. Originaltexte können lokal mit IDs und Feldpfaden zugespielt werden.

## Unveränderliche Spielstruktur

Nur zuvor als sichtbar identifizierte Textfelder bearbeiten. IDs, Bedingungen,
Kosten, Effekte, Zahlenwerte, Referenzen, technische Namen und Pfade erhalten.
HTML-/Rich-Text-Tags, Platzhalter wie `{0}`, Qualitätsmarker wie `[q:123]`
sowie Schlüssel und Schwellen von Stufentabellen ebenfalls erhalten.

Technische englische Namen können auch in einem vollständig übersetzten
Addon erforderlich sein. Ein globales Suchen-und-Ersetzen ist ungeeignet.
Eigennamen und ausgeschlossene technische Felder brauchen einen erklärten
Status, damit sie nicht später versehentlich bearbeitet werden.

## Menüs, Buttons und feste Texte

Im Paket liegen die geprüften Textänderungen für `Sunless.Game.dll` und
`FailBetter.Core.dll` in `package/ui/ui-manifest.json` und
`package/core/core-manifest.json`. Die Zuordnung erfolgt nach Methode und
Instruktionsposition, mit ursprünglichem und übersetztem Text.
`package/ui/Patch-UI.ps1` verwendet dafür Mono.Cecil.

Diese Manifestdateien enthalten englische Vergleichsliterale, die der
Originalprüfung dienen. Sie sind keine reine deutsche Übersetzungstabelle.
Für neue Zielsprachen müssen die Ausgabedateien neu erzeugt, strukturell
geprüft und ihre neuen erwarteten Prüfsummen ermittelt werden. Der vorhandene
Patcher ist auf die mitgelieferten deutschen Ergebnisse festgelegt.

`ContextButtonDictionary`, `HotkeysDictionary` und als Eingabeschlüssel
verwendetes `Use` bleiben unverändert. Sie steuern Aktionen im Spiel.
Nach Änderungen sind insbesondere Hafenknopf, Ablegen und Tastenkürzel
funktional zu testen; eine reine Zeichenkettenprüfung reicht dafür nicht.

`package/resources/resource-patch-spec.json` und `Patch-Resources.ps1`
betreffen feste Beschriftungen in `resources.assets`. Die vorhandenen
Bytepositionen und Längen sind versionsgebunden. Eine längere Übersetzung
darf nicht einfach an dieselbe Stelle geschrieben werden.

## Erforderliche Prüfungen für eigene Änderungen

1. Unveränderte Ausgangsdateien der unterstützten Spielversion sichern und
   ihre Prüfsummen kontrollieren.
2. Nur freigegebene Textfelder ersetzen; Objektstruktur und Verknüpfungen
   gegen die Originaldaten prüfen.
3. Platzhalter, Tags und Stufenschlüssel vergleichen; JSON erneut einlesen.
4. Übersetzungsstatus und bewusst erhaltene Namen getrennt ausweisen.
5. Neues Paket mit neuen Prüfsummen und eigener Versionsnummer bauen.
6. Installation, Rückbau und reinen Addon-Modus in einer Testkopie prüfen.
7. Im Spiel auf abgeschnittene Beschriftungen, Umlaute, Sonderzeichen,
   Zeilenumbrüche und funktionierende Bedienelemente testen.

Die genaue unterstützte Fassung und die Grenzen der bisherigen Prüfung
stehen in `COMPATIBILITY.txt`.

## Weiterverwendung und Quellen

Eigene weitere Übersetzungen und Verbesserungen sind willkommen. Für die
veröffentlichten eigenen Hilfsskripte und Anleitungen erlaubt das Projekt
Verwendung, Bearbeitung und Weitergabe, soweit es eigene Rechte daran
einräumen kann. Dabei „Unterzee Deutsch / ByteArchiv“ mit Projektlink nennen
und eigene Änderungen kenntlich machen. Die genaue Abgrenzung steht in
[REUSE-AND-CREDITS.txt](REUSE-AND-CREDITS.txt). Spielinhalte und abgeleitete
Übersetzungstexte sind von dieser Werkzeugfreigabe nicht erfasst.

Sunless Sea ist © und ™ Failbetter Games Limited. Dies ist ein inoffizielles
Fanwerk. Die schöpferische Grundlage stammt vom Team hinter Sunless Sea und
Zubmariner. Die deutsche Übersetzung dieses Projekts wurde mit generativer
KI erstellt, ohne Übersetzungstexte oder Mitarbeit früherer Fanübersetzerteams
zu übernehmen. Das ist keine vollständige menschliche Qualitätsprüfung.

Hilfreiche offizielle Quellen:
[Spielseite](https://www.failbettergames.com/games/sunless-sea),
[Fan-Projekt-Richtlinien](https://www.failbettergames.com/fan-project-guidelines),
[Modding-Demo](https://www.failbettergames.com/news/modding-sunless-sea-a-demo)
und [Modding Guidelines](https://steamcommunity.com/app/304650/discussions/1/530649887200384697/).

Die offiziellen Modding-Hinweise empfehlen, nur tatsächlich bearbeitete
Objekte in ein Addon aufzunehmen und Konflikte mit anderen Mods zu beachten.
Bei Ersetzungen müssen die ursprünglichen IDs erhalten bleiben; neue Objekte
benötigen eigene IDs. Die Anleitung beschreibt das JSON-Addon-Verfahren,
keine Freigabe unserer zusätzlichen Änderungen an Programmdateien.
