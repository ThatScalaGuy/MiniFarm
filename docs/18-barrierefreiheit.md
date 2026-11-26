# 18 – Barrierefreiheit und Inklusion

> MiniFarm soll für **alle** Kinder spielbar sein, auch für Kinder mit motorischen, visuellen, auditiven oder kognitiven Besonderheiten, sowie für neurodiverse Kinder (z. B. Autismus-Spektrum, ADHS, sensorische Empfindlichkeit). Das beruhigende, druckfreie Konzept ist hierfür eine gute Basis; dieses Dokument macht es verbindlich und prüfbar.

## 1. Leitlinien

1. **Mehrere Kanäle:** Jede Information über mindestens zwei Kanäle (Bild + Ton, Form + Farbe, Bewegung + Haptik).
2. **Kein Zeitdruck, keine Präzisionspflicht.** (Basis des Spiels; hilft auch motorisch eingeschränkten Kindern.)
3. **Anpassbar:** Eltern können Reize, Tempo und Hilfen feinjustieren (Elternbereich, Doc 17).
4. **Vorhersagbar:** Rituale (Tagesablauf, Abendritual) schaffen Orientierung; plötzliche Überraschungen vermeiden.
5. **Respektvolle Darstellung:** Vielfalt in Figuren; keine Stereotype; Hilfsmittel (z. B. Rollstuhl, Hörgerät) als normale Details möglich.

## 2. Anforderungen nach Bereichen

### 2.1 Motorik
| Maßnahme | Detail |
|---|---|
| Ein-Finger-Bedienung | Alle Kernaktionen mit einem Finger; Tippen-statt-Ziehen-Alternative immer vorhanden |
| Große Ziele & Magnet | ≥ 64 pt; Zielmagnet; Hilfen auch dauerhaft einstellbar („Immer helfen“) |
| Autopilot | Fahrzeuge fahren auf Wunsch selbst (Doc 11) |
| Kein Halten/Timing nötig | „Halten“-Aktionen haben Tipp-Alternative |
| **Switch Control / Zugriff** | Jede Aufgabe über Wechselschalter lösbar (Zielwahl via Fokus-Ring, Doc 18 §3) |
| **AssistiveTouch** | Kompatibel (keine Gesten, die dem System widersprechen) |

### 2.2 Sehen
| Maßnahme | Detail |
|---|---|
| Kontrast | Interaktive Elemente mit starken Luminanz-Kontrasten (≥ 4,5:1 zum Hintergrund) |
| Farbe nie allein | Form/Piktogramm/Ton zusätzlich; Farbenblind-Prüfung (Protanopie, Deuteranopie, Tritanopie) |
| Große Piktogramme | min. 64 pt; Option „Große Symbole“ (+25 %) |
| **VoiceOver** | Elternbereich vollständig; Spielwelt: eingeschränkt, siehe §3 |
| Audio-Beschreibung | Pelle spricht ohnehin alles wichtige; Szenen-Beschreibung per „Pelle, was siehst du?“ (Option) |
| Lichtempfindlichkeit | Keine Blitz-Effekte (> 3 Blitze/s); Bloom dezent |

### 2.3 Hören
| Maßnahme | Detail |
|---|---|
| **Untertitel-Blasen** | Piktogramm + kurzer Text (optional), für alle Pelle-Zeilen (Transkript aus Katalog) |
| Visuelle Signale für Töne | Klingel, Hofhahn, Tier-Rufe mit sichtbarem Pendant (Animation/Partikel) |
| Aufgaben nie nur über Ton | Hinweis-Stufen enthalten immer visuelle Cues (Cue, Ghost-Hand) |
| Hörgeräte/Kopfhörer | Lautstärke-Bus-Regler; Mono-Option (`Audio → Mono`) |

### 2.4 Kognition & Neurodiversität
| Maßnahme | Detail |
|---|---|
| **Vorhersagbarkeit** | Feste Tagesstruktur, Rituale, gleiche Position von HUD-Elementen |
| **Reizreduktion** | „Ruhiger Modus“: weniger Partikel, Musik aus, gedämpfte Effekte, minimaler Idle-Lärm |
| **Tempo** | „Langsame Sprache“, mehr Pausen, Hilfen früher |
| **Kein Überraschungs-Lärm** | Alle lauten Effekte vorher angekündigt oder gedämpft; Pegel-Limiter |
| **Wiederholung erlaubt** | Dieselbe Aufgabe beliebig oft (Spezialinteressen: z. B. nur Traktor fahren) – **freies Spiel** immer möglich |
| **Visuelle Struktur** | Rezeptkarten/Bildfolgen (Visual Schedule), klare Reihenfolge |
| **Keine Mehrfach-Aufgaben-Zwang** | Aufgaben sind einzeln, eine zur Zeit im Fokus |
| **Kein Wettbewerb** | Keine Ranglisten, keine Zeit, kein Scheitern |

### 2.5 Sprache
- **Icon-first:** Kein Lesen nötig; Lokalisierung nur Audio.
- **Einfache Sprache:** Kurze Sätze, Alltagswörter, keine Redewendungen (Doc 12).
- **Mehrsprachige Familien:** Sprachwahl im Elternbereich; Bilingual-Wortschatz-Modus später.

## 3. Apple-Barrierefreiheits-Funktionen (Checkliste)

| Funktion | Umsetzung |
|---|---|
| **VoiceOver** | Elternbereich vollständig; Spielwelt: zugängliche Entities (`AccessibilityComponent` in RealityKit: Label, Traits, Aktionen) für Hauptinteraktionen (Wünsche, Orte, Werkzeuge); Fokus-Reihenfolge logisch (HUD → Wünsche → Welt-Objekte) |
| **Switch Control** | Fokus-Ring-Navigation über HUD und Wunsch-Blasen; Aufgaben mit „Tippen“-Alternative lösbar |
| **Voice Control** | Beschriftete HUD-Elemente (Accessibility Labels), auch wenn Kind-UI textfrei ist |
| **Reduce Motion** | Kamerafahrten → Überblendungen; Partikel reduziert; Wackel-/Hüpf-Animationen gedämpft |
| **Reduce Transparency / Increase Contrast** | Überlagerungen/Umrisse stärker; Cutaway-Transparenz → Ausblenden |
| **Dynamic Type** | Elternbereich (nicht Kind-UI) |
| **Bold Text / Button Shapes** | Elternbereich berücksichtigen |
| **Larger Accessibility Sizes** | HUD-Skalierung „Große Symbole“ |
| **Guided Access** | Spiel gut nutzbar (Eltern sperren Tasten); Gate beachtet Guided-Access-Sitzungen |
| **Assistive Access (iOS 17+)** | Unterstützung prüfen (Stand prüfen): reduzierte, vereinfachte Oberfläche; Spiel in Vollbild |
| **Mono-Audio / Balance** | Voice nicht nur über einen Kanal; Mono-Mix |
| **Captions/Untertitel** | eigene Blasen (siehe oben) |
| **Haptik** | abschaltbar; nicht zwingend zur Aufgabenlösung |

## 4. Ruhige-Modus-Presets (Elternbereich)

| Preset | Wirkung |
|---|---|
| **Standard** | Alle Effekte normal |
| **Ruhig** | Partikel −70 %, Musik −8 dB und nur Schlaflied/Wiegenmotive, Idle-Tiergeräusche seltener, Kamerabewegung langsamer |
| **Sehr ruhig** | Wie Ruhig + Musik aus, nur Sprachführung + zentrale Interaktions-SFX, kein Wetter-Partikel |
| **Visuell klar** | Hoher Kontrast, Silhouetten-Outlines an allen Interaktiven, große Symbole |
| **Mehr Hilfe** | Hilfe-Stufen früher (×0,5 Zeit), Magnet-/Ziel-Größen max. |

## 5. Test und Verifikation

| Test | Methode |
|---|---|
| Automatisiert | Accessibility Audit (Xcode, `performAccessibilityAudit`), Kontrast-Checks |
| VoiceOver/Switch | Manuelles Durchspielen der Kernpfade (Elternbereich 100 %, Welt 80 %) |
| Farbenblindheit | Simulationen (Color Oracle, Xcode Accessibility Inspector) |
| Reduce Motion | Alle Kamerafahrten und Partikel geprüft |
| Playtests | Kinder mit motorischen/sensorischen Besonderheiten (mit Eltern/Therapeut:innen), Feedback einholen |
| Fachliche Beratung | Frühpädagog:in/Ergotherapeut:in für Review des Konzepts (empfohlen) |

## 6. Barrierefreiheit im App Store

- **Accessibility Nutrition Labels** in App Store Connect (VoiceOver, Voice Control, Larger Text, Dark Interface n/a, Differentiate Without Color, Sufficient Contrast, Reduced Motion, Captions, Audio Descriptions u. a.): ehrlich ausfüllen, nur Unterstütztes angeben (Stand prüfen).
- Dokumentation der Unterstützung auf der Webseite.
