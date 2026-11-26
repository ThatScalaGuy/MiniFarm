# 17 – Elternbereich, Datenschutz, Compliance und Premium-Modell

> MiniFarm richtet sich an Kinder ab 3 Jahren. Das bedeutet höchste Anforderungen an Datenschutz und Sicherheit: **keine Werbung, kein Tracking, keine Konten, keine Netzwerkverbindung im Spiel, keine In-App-Käufe.** Nichts davon ist verhandelbar.
>
> ⚠️ **Hinweis:** Dies ist eine technisch-konzeptionelle Zusammenstellung, **keine Rechtsberatung**. Gesetze und App-Store-Richtlinien ändern sich; vor Release juristisch und gegen die aktuellen Apple-Richtlinien prüfen („Stand prüfen“).

## 1. Leitprinzipien

1. **Data Not Collected:** Die App erhebt keine Daten, die das Gerät verlassen. Ziel-Privacy-Label im App Store: **„Data Not Collected“**.
2. **Offline-first:** Kein Netzwerkzugriff im Spiel. (Optional: Netzwerk nur für Apple-Dienste wie StoreKit beim Kauf/Restore und App-Store-Updates – nicht durch die App initiiert.)
3. **Keine Third-Party-SDKs** (Analytics, Ads, Crash-Reporting, Attribution) – Apple Guideline 5.1.4 (Kids Category).
4. **Keine Accounts, keine Logins, keine Social-Funktionen, kein Chat, kein UGC-Austausch.**
5. **Eltern entscheiden:** Alle Einstellungen und alles, was die Kinderumgebung verlässt, liegen hinter einem Parental Gate.
6. **Datensparsamkeit:** Es werden nur Spielstände und adaptive Parameter lokal gespeichert; Löschung jederzeit.

## 2. Der Elternbereich

Zugang: Zahnrad auf Startbildschirm/Pausenmenü → **Parental Gate** (Doc 11 §8).

| Bereich | Inhalt |
|---|---|
| **Profile** | Bis zu 4 lokale Profile anlegen/löschen (Tier-Avatar statt Foto/Name); Profil-Stage manuell setzen („Startniveau“) |
| **Lernbegleitung** | Qualitative Übersicht („Übt gerade: Zählen, Fahren“); **keine** Scores/Vergleiche/Diagnosen; Tipps für Eltern zum Mitspielen (z. B. „Fragen Sie: Wie viele Äpfel sind das?“) |
| **Spiel-Einstellungen** | Adaptivität an/aus, Merk-Modus, Hilfen früher/später, Schwierigkeit-Vorgabe |
| **Sitzung** | Spiel-Timer (z. B. 15/30/45 min; sanfter Abschluss „Zeit zum Schlafen“ + Abend-Ritual), Pausen-Erinnerung |
| **Audio** | Lautstärken (Voice/SFX/Ambient/Musik), „leises Spiel“, Sprechtempo, Untertitel-Blasen |
| **Sensorik/Barrierefreiheit** | Reduce Motion/Partikel-Intensität, Haptik, Kontrast, große Ziele |
| **Persönliche Stimme** | Kindesname aufnehmen (Mikrofon), Gute-Nacht-Sätze aufnehmen; Löschen |
| **Daten** | Fortschritt zurücksetzen, Profil löschen, Datenübersicht („Was ist gespeichert?“) |
| **Familie** | Hinweis auf Apple Family Sharing (Kauf teilen) |
| **Info/Support** | Datenschutzerklärung, Impressum, Kontakt, Credits (inkl. KI-Hinweis, siehe §6), Rezension-Link (alle externen Links gated) |
| **Mitspielen** | Anleitung Co-Play (iPad zwei Cursor) |

**Eltern-UI:** normaler Text, Dynamic Type, VoiceOver-vollständig; nicht kindlich gestaltet (klar erwachsen, nüchtern).

## 3. Datenschutz-Konzept

### 3.1 Datenkategorien

| Daten | Wo | Zweck | Verlässt Gerät? |
|---|---|---|---|
| Spielstand (Hof, Pflanzen, Tiere) | Gerät, App-Container | Spielen | ❌ |
| Adaptive Fähigkeits-Parameter | Gerät | Anpassung | ❌ |
| Einstellungen | Gerät | Konfiguration | ❌ |
| Aufgenommener Kindesname / Eltern-Sätze (optional) | Gerät | Personalisierung | ❌ |
| Gerätekennungen, IDFA, IDFV, Standort, Kontakte, Fotos | – | – | **werden nicht erhoben** |
| Absturzdaten | Apple (System-Organizer, nur wenn Nutzer an Apple teilt) | Stabilität | Durch Apple, nicht durch App |

### 3.2 Technische Maßnahmen
- Kein `URLSession`/Netzwerk-Code im Spiel-Target (CI-Check: keine Netzwerk-Imports im Kids-Target; Network-Entitlement nicht anfordern, soweit möglich).
- **App Transport Security** unverändert; keine Domains.
- **Data Protection:** Spielstände mit `NSFileProtectionComplete`/`CompleteUntilFirstUserAuthentication`.
- **Mikrofon:** Berechtigung wird **nur** im Elternbereich auf Anforderung angefragt (`NSMicrophoneUsageDescription` mit klarem Text); Aufnahmen lokal; nie übertragen; jederzeit löschbar.
- **iCloud/Backup:** Standard-Geräte-Backups (verschlüsselt durch Apple) möglich; kein eigener Cloud-Sync. Aufnahmen optional vom Backup ausnehmen (`isExcludedFromBackup`) – Entscheidung offen (Doc 23).
- **Privacy Manifest** (`PrivacyInfo.xcprivacy`) vollständig und korrekt (Required-Reason-APIs: z. B. UserDefaults, File-Timestamps – jeweils mit zulässigem Grund).

### 3.3 Rechtliche Rahmen (Überblick, Stand prüfen)

| Rahmen | Relevanz | Umsetzung |
|---|---|---|
| **DSGVO / GDPR** (EU) | Verarbeitung personenbezogener Daten von Kindern; besonderer Schutz | Keine Erhebung → minimale Pflichten; Datenschutzerklärung dennoch Pflicht; Einwilligungsalter in DE: 16 (nur relevant, wenn Daten verarbeitet würden) |
| **COPPA** (USA, Kinder < 13) | Online-Dienste, die Kinder-Daten erheben | Keine Erhebung; **Privacy Policy** + keine Verhaltens-Werbung; Compliance-Doku |
| **UK Age Appropriate Design Code** | Standards für Kinder-Dienste | Konform durch Datensparsamkeit und Voreinstellungen |
| **Apple App Store Review Guidelines** | 1.3 Kids Category, 5.1.4 Kids, 5.1.1 Datenschutz | siehe §4 |
| **Jugendmedienschutz (JMStV/USK)** | Alterseinstufung | Apple-Altersfreigabe 4+ (Fragebogen); optional freiwillige Kennzeichnung (Stand prüfen) |
| **EU AI Act / KI-Kennzeichnung** | Transparenz bei KI-generierten Inhalten (Stimmen/Musik) | Hinweis in Credits/Elternbereich; Rechtsprüfung (Stand prüfen) |
| **Barrierefreiheitsstärkungsgesetz (BFSG)/EAA** | Digitale Produkte/Dienste, ggf. Kleinstunternehmen-Ausnahme | Barrierefreiheit gemäß Doc 18 |
| **Impressumspflicht (DDG)** | Anbieterkennzeichnung | Im Elternbereich + Webseite |

## 4. Apple Kids Category – Checkliste

| Anforderung | Umsetzung |
|---|---|
| **Altersband wählen** (5 & unter / 6–8 / 9–11) | **„5 & unter“** (Hauptzielgruppe 3–5; 6–8 wird ebenfalls bedient). Entscheidung offen (Doc 23): Band „5 & under“ ist strenger, passt aber zur Positionierung |
| **Keine Third-Party-Analytics/-Werbung** | ✅ keine SDKs |
| **Parental Gate vor externen Links, Käufen, Einstellungen, Social** | ✅ Doc 11 §8 |
| **Datenschutzerklärung in App und App Store Connect** | ✅ Link nur hinter Gate |
| **Keine Links zu externen Webseiten ohne Gate** | ✅ |
| **Keine Anfragen nach persönlichen Daten** | ✅ |
| **Altersgerechte Inhalte, keine Gewalt/Horror** | ✅ Designprinzipien Doc 01 |
| **Privacy Nutrition Label korrekt** | „Data Not Collected“ |
| **Altersfreigabe-Fragebogen** | alle „Keine“ → 4+ |
| **Declared Age Range API** | Nicht nötig (keine altersabhängigen Funktionen, keine Accounts); Bewertung offen (Stand prüfen) |
| **App-Beschreibung/Screenshots kindgerecht und ehrlich** | Screenshots nur Spielbilder; keine Versprechungen medizinischer/pädagogischer Wirkung |
| **Kinderschutz bei Mikrofon/Kamera** | Mikrofon nur Elternbereich; keine Kamera |

## 5. Premium-Modell

| Aspekt | Entscheidung |
|---|---|
| **Modell** | **Einmalkauf (Paid App)** – vollständiges Spiel, keine Freischaltungen |
| **Keine** | In-App-Käufe, Abos, Werbung, Loot-/Zufallsmechaniken, „Kaufen für schneller“ |
| **Preis-Empfehlung** | ca. **4,99 – 6,99 €** (Tier-Preis, regional; Wert-Erwartung für Premium-Kinderspiele; Stand/Markt prüfen); Launch-Aktion optional (nicht als Druckmittel) |
| **Family Sharing** | Aktiviert (Familienmitglieder teilen den Kauf) |
| **Test/Demo** | Keine Demo-App mit Pay-Wall; stattdessen gute Screenshots + **App-Preview-Video**; optional freie „Mini-Hof“-Lite-Version (ohne IAP, Verlinkung ohne Druck) – Entscheidung offen (Doc 23) |
| **Updates** | Kostenlose Inhalts-Updates (Jahreszeit-Feste, neue Tiere) – kein Season-Pass |
| **Provision** | Apple Small Business Program (15 %, wenn berechtigt, Stand prüfen) |
| **Alternative** | Aufnahme in Apple Arcade (Kids-geeignet; Verhandlungsfrage, nicht planbar) |

**Begründung:** Premium + keine IAP passt zur Haltung (ruhig, kein Druck) und vereinfacht die Compliance (kein Gate für Käufe im Spiel nötig, kein Zahlungsfluss mit Kindern).

## 6. KI-Transparenz und Credits

- Audio (Sprache/SFX/Musik) wird teilweise mit KI-Werkzeugen erzeugt (Doc 13).
- **Offenlegung** in Credits/Elternbereich: „Sprachausgabe und Teile der Klänge wurden mit KI-Unterstützung erstellt.“ (Formulierung juristisch prüfen.)
- **Menschliche Verantwortung:** Alle Texte von Menschen geschrieben/geprüft; alle Audios manuell abgenommen.
- **Stimmrechte:** Dokumentation der Voice-Lizenzen (Doc 13 §8).

## 7. Sicherheit des Elternbereichs

- Gate nach **App-Start** und **bei jedem** Aufruf (kein Sitzungs-Bypass) – Zeitfenster max. 5 min nach erfolgreichem Gate.
- Gate-Aufgaben randomisiert, nicht per VoiceOver für Kinder triviale Lösung (Alternativ-Aufgabe nur bei aktivem VoiceOver).
- Keine Passwort-Speicherung nötig; optional Geräte-Authentifizierung (Face ID/Touch ID) als Alternative für Eltern (`LocalAuthentication`) – Entscheidung offen.

## 8. Dokumentation für Store und Audits

| Dokument | Inhalt |
|---|---|
| Datenschutzerklärung (DE/EN) | Einfach, ehrlich: „Wir erheben keine Daten.“ |
| Privacy Manifest | `PrivacyInfo.xcprivacy` |
| Compliance-Memo | COPPA/DSGVO/Kids-Category-Einordnung |
| SDK-Inventar | „Keine Third-Party-SDKs“ (Nachweis in Build-Konfiguration) |
| Lizenz-Dokumentation | Audio-/Asset-Lizenzen, Schriften, Open-Source-Hinweise |
| Support-Prozess | Support-E-Mail/Webseite; Reaktionszeit; Datenlöschung-Anleitung |

## 9. Risiken

| Risiko | Gegenmaßnahme |
|---|---|
| Review-Ablehnung (Kids Category) | Frühe Checkliste (§4), Reviewer-Notizen mit Anleitung zum Gate |
| Mikrofon-Funktion wird beanstandet | Klare Elternbereich-Beschränkung, Begründung; im Notfall Feature entfernen (optional) |
| KI-Stimmen-Rechte unklar | Frühe Lizenzprüfung, schriftliche Dokumentation, Alternativen (Sprecher:in) |
| Gesetzesänderungen (AI Act, COPPA-Update) | Periodische Prüfung vor jedem Release |
