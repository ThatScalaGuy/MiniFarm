# MiniFarm-Modelle

Die Dateien in `App/Resources/Models/` werden offline geladen. Der Dateiname
entspricht `model.<ID>.usdz` (z. B. `model.animal.dog.usdz`); Pflanzen ergänzen
das Stadium `seed`, `sprout`, `growing` oder `ripe`, Tierbabys `.baby`.
`manifest.json` ordnet die IDs den Dateien zu und enthält tatsächliche
Byte-Größe, USD-Achse, Maßstab, Weltgrenzen, Dreiecke und Animationen.
Für animierte Dateien gelten die Grenzen zum ersten Zeitschritt
(`boundsTimeCode`); statische Dateien nutzen den USD-Default-Zustand.

Alle USDZ-Dateien sind Y-up, mit einem Meter pro Einheit; der Boden liegt bei
Y=0. Die 16 × 12 m große `terrain.island`-Scholle reicht unter die Bodenebene.
Das Manifest enthält die bestätigte `frontAxis` je Modell; `null` bedeutet,
dass keine Vorderseite festgelegt wurde. Die Tiermodelle schauen nach −Z,
Menschen und Gebäude nach +Z, statische Fahrzeuge und angehängte Geräte nach −X.
Für die +Z-Vorwärtsrichtung der App benötigen Tiere eine Y-Drehung um 180°
und statische Fahrzeuge eine Y-Drehung um +90°. Animierte Fahrzeugvarianten
schauen bereits nach +Z. Saatbeutel und Produkte mit gestalteter Vorderseite
zeigen nach +Z; richtungsneutrale Produkte haben keine festgelegte Vorderseite.
Die `item.*`-Dateien stellen geerntete bzw. verarbeitete Waren und Saatbeutel
dar, nicht die `crop.*`-Wachstumsstadien. Das Quellkoordinatensystem in
Blender ist Z-up. Die Vorschau verwendet die exportierten Objekte auf einer eigens
gebauten Illustrationsfläche, nicht das Landschaftsmodell in Originalgröße.

Die 19 Tierdateien enthalten jeweils eine unbenannte, zweisekündige
Transform-Idle-Bewegung (24 Zeitschritte pro Sekunde, Zeitcodes 1–49), keine
benannten Skelett-Clips. Die Wiedergabe von Pelle, Minka und Huhn wurde unter
macOS mit RealityKit auf tatsächliche Transformänderungen geprüft; auf einem
iOS-Gerät steht der Test noch aus.

Die `anim.*.usdz`-Dateien sind eigenständige **vollständige Modellvarianten**,
keine an ein anderes Modell bindbaren Skelett-Clips. Ihre Manifest-ID enthält
das Präfix `anim.`; `variantOf` benennt die Modell-ID ohne `model.`-Präfix,
`motion` die Bewegung. Pelle geht auf der
Stelle, wedelt oder wird gebürstet; Minka geht oder schmiegt sich an; Hühner
gehen oder picken. Acht Fahrzeug- und Gerätevarianten bewegen ihre Räder auf
der Stelle. Auf macOS wurde die RealityKit-Wiedergabe aller 15 Varianten
geprüft; die Wurzelanimation bewegt beim Hund alle vier Beine und beim Traktor
alle vier Räder. Für eine Variante wird deren eigenes Modell geladen und dessen
Wurzelanimation sofort wiederholt. Die USD-Default-Pose vor der Wiedergabe kann
bewegte Teile falsch platzieren; für einen ruhenden Zustand das entsprechende
`model.*` verwenden. Weitere Animationen und Cutaway-Logik fehlen noch.

## Reproduktion

Mit Blender 5.2 in einem **separaten Hintergrundprozess**:

```sh
blender --background --factory-startup --python Tools/Blender/animals.py
blender --background --factory-startup --python Tools/Blender/crops.py
blender --background --factory-startup --python Tools/Blender/environment.py
blender --background --factory-startup --python Tools/Blender/people.py
blender --background --factory-startup --python Tools/Blender/terrain.py
blender --background --factory-startup --python Tools/Blender/crop_items.py
blender --background --factory-startup --python Tools/Blender/product_items.py
blender --background --factory-startup --python Tools/Blender/animal_clips.py
blender --background --factory-startup --python Tools/Blender/vehicle_clips.py
blender --background --factory-startup --python Tools/Blender/inspect_assets.py -- \
  --output App/Resources/Models/manifest.json
blender --background --factory-startup --python Tools/Blender/preview_farm.py -- \
  --output /tmp/minifarm-preview.png
python3 Tools/Blender/check_assets.py
xcrun swift Tools/Blender/check_realitykit.swift
xcrun swift Tools/Blender/check_realitykit.swift --parts
xcrun swift Tools/Blender/check_realitykit.swift --aggregate \
  App/Resources/Models/anim.animal.dog.walk.usdz Leg Leg_001 Leg_002 Leg_003
xcrun swift Tools/Blender/check_realitykit.swift --aggregate \
  App/Resources/Models/anim.veh.tractor.wheels.usdz \
  Rolling_wheel Rolling_wheel_001 Rolling_wheel_002 Rolling_wheel_003
```

Auf macOS kann für `blender` der ausführbare Pfad in der Blender-App verwendet
werden. Jeder Generator erstellt eine eigene Szene und überschreibt nur seine
jeweiligen Ausgabedateien. `usdchecker --arkit --strict <modell.usdz>` prüft die
USDZ-Kompatibilität; ein RealityKit-Laufzeittest bleibt zusätzlich nötig.
