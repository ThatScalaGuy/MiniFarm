# MiniFarm-Modelle

Die Dateien in `App/Resources/Models/` werden offline geladen. Der Dateiname
entspricht `model.<ID>.usdz` (z. B. `model.animal.dog.usdz`); Pflanzen ergänzen
das Stadium `seed`, `sprout`, `growing` oder `ripe`, Tierbabys `.baby`.
`manifest.json` ordnet die IDs den Dateien zu und enthält tatsächliche
Byte-Größe, USD-Achse, Maßstab, Weltgrenzen, Dreiecke und Animationen.

Alle USDZ-Dateien sind Y-up, mit einem Meter pro Einheit; der Boden liegt bei
Y=0. Die 16 × 12 m große `terrain.island`-Scholle reicht unter die Bodenebene.
Die meisten Figuren schauen entlang −Z. Das Quellkoordinatensystem in Blender
ist Z-up. Die Vorschau verwendet die exportierten Objekte auf einer eigens
gebauten Illustrationsfläche, nicht das Landschaftsmodell in Originalgröße.

Die 19 Tierdateien enthalten jeweils eine unbenannte, zweisekündige
Transform-Idle-Bewegung (24 Zeitschritte pro Sekunde, Zeitcodes 1–49), keine
benannten Skelett-Clips. RealityKit-Wiedergabe und Looping sind noch auf dem
Zielgerät zu prüfen. Die übrigen Modelle sind statisch; Lauf-, Pflege- und
Maschinenanimationen sowie Cutaway-Logik sind noch nicht enthalten.

## Reproduktion

Mit Blender 5.2 in einem **separaten Hintergrundprozess**:

```sh
blender --background --factory-startup --python Tools/Blender/animals.py
blender --background --factory-startup --python Tools/Blender/crops.py
blender --background --factory-startup --python Tools/Blender/environment.py
blender --background --factory-startup --python Tools/Blender/terrain.py
blender --background --factory-startup --python Tools/Blender/inspect_assets.py -- \
  --output App/Resources/Models/manifest.json
blender --background --factory-startup --python Tools/Blender/preview_farm.py -- \
  --output /tmp/minifarm-preview.png
```

Auf macOS kann für `blender` der ausführbare Pfad in der Blender-App verwendet
werden. Jeder Generator erstellt eine eigene Szene und überschreibt nur seine
jeweiligen Ausgabedateien. `usdchecker --arkit --strict <modell.usdz>` prüft die
USDZ-Kompatibilität; ein RealityKit-Laufzeittest bleibt zusätzlich nötig.
