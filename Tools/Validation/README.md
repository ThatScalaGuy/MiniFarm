# Release-Bundle lokal prüfen

```sh
Tools/Validation/check-build.sh
```

Voraussetzungen: macOS mit ausgewähltem Xcode, Swift 6, iOS-Simulator-SDK ab 18, XcodeGen 2.46.0, Python 3.9+ sowie Apples `usdchecker` und `afconvert`. Der Einstieg verwendet das eingecheckte `MiniFarm.xcodeproj`. Er generiert zusätzlich im temporären Verzeichnis aus `project.yml` ein Vergleichsprojekt, damit kein grüner Build mit fehlenden Swift-Quellen oder Tests möglich ist. Bei einer Abweichung `xcodegen generate` im Checkout ausführen.

Das Skript testet die Fehlerpfade, baut das Scheme `MiniFarm` in **Release** für einen generischen Simulator und prüft **dasselbe Buildprodukt**. Es startet keinen Simulator, signiert nichts und entfernt seine privaten DerivedData. Für ein bereits gebautes, **unsigniertes Release-Produkt aus demselben Checkout**:

```sh
python3 Tools/Validation/check_bundle.py /pfad/zur/MiniFarm.app
```

Der Prüfer vergleicht Dateinamen (inklusive Groß-/Kleinschreibung) und die unverändert kopierten Kataloge, Manifeste und Medien mit dem Checkout. Er lädt `Content/` aus der App mit dem produktiven Swift-`FarmCatalog`. Seine Pflanzenstadien, Tier-/Gerätemodelle und Tierlaute müssen sich in den passenden Manifesten auflösen. Modell-`id` plus `model.` ergibt den Runtime-Basisnamen; `file` und `bytes` müssen zur wirklichen Datei passen. Es gibt keine fest verdrahtete Modell- oder Clipanzahl.

Ein deklarierter deutscher `voice`-Eintrag ohne `path` bzw. mit `null` ist ein lokaler Speech-Fallback; den Text liefert der Spielkontext oder `subtitle`. Er zählt nicht als Aufnahme. Sobald `path` gesetzt ist, muss die Datei existieren und decodierbar sein, auch bei Sprache. SFX, Musik und Ambiente brauchen immer eine Datei.

Vor Inhaltsprüfungen verwirft das Tool unerwartete Dateien, Links und nicht deklarierte Medien anhand ihrer Metadaten. USDZ-Einträge werden vor jeder CRC-/USD-Prüfung geprüft und nie entpackt. Danach laufen der vorhandene `Tools/verify_bundle.py`, Apples USD-Prüfer im ARKit-Modus und die Audiodecodierung ohne Wiedergabe. Ein Fund liefert Exitcode 1; die Inhalte verdächtiger Dateien und rohe Ausgaben der Medienwerkzeuge werden nicht geloggt.

Der macOS-Workflow prüft außerdem die bestehenden Offline-Audiowerkzeuge und führt `MiniFarmTests` auf einem CI-iPhone-Simulator aus. Es gibt weder Upload noch Audio-API-Aufruf. Dies ist ein Paketprüfpunkt, kein Nachweis für Animation, Hörqualität, Offline-Verhalten zur Laufzeit oder eine bestandene Geräte-/Spielabnahme.
