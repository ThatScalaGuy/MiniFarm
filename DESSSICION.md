# MiniFarm: Entscheidungen für die lokale App

Diese Annahmen sind änderbar. Inhaltliche Konflikte werden nach Doc 21 und Doc 16 aufgelöst.

| Entscheidung | Grund | Alternative oder offene Prüfung |
|---|---|---|
| Zielgruppe 3 bis 7 Jahre, Deutsch zuerst. Die drei Entwicklungsstufen bleiben ohne Alterszwang. | Das aktuelle Briefing hat Vorrang vor „3 bis 8“ im Konzept. | Weitere Altersgruppen oder Sprachen nach gesondertem Test. |
| XcodeGen ist die Quelle; das generierte Projekt und das geteilte Scheme gehören ins Repository. Swift 6, Deployment Target 18.0, beide Gerätefamilien. | Direkter Einstieg in Xcode und reproduzierbare Projektstruktur. | Manuell gepflegtes Projekt wäre schwieriger mit Komponenten-Branches zu synchronisieren. |
| Persönliches Entwicklungsteam Sven Herrmann (`V75G3N885G`). | Der Name der Organisation und die Team-ID stammen aus dem öffentlichen Apple-Development-Zertifikat. Ein anderes Zertifikat für denselben Entwickler gehört zu einer Firma. | Simulator ohne Provisioning. Geräteinstallation separat mit gültigem persönlichem Profil prüfen. |
| Lokale Offline-Ressourcen als Ordner `Content`, `Models`, `Audio` im App-Bundle. | Stabile IDs und Pfade, keine Netzlaufzeit und keine Dateinamenskollisionen. | Flach kopierte Ressourcen würden die Datenverträge brechen. |
| Hochformat und beide Querformate, zusätzlich umgekehrtes Hochformat auf dem iPad; eine aktive Spielszene. | Das Kind kann das Gerät drehen, ohne den Hof oder die laufende Aufgabe zu wechseln. | Mehrfensterbetrieb bräuchte explizite Synchronisation des aktiven Profils. |
| Kein Store-Upload, keine Leitsystem- oder Releasefreigabe aus automatischen Tests ableiten. | Kinder-Playtests, Rechteprüfung, Gerätetests und redaktionelle Abnahmen lassen sich nicht simulieren. | Geführter Familien-Test mit Einwilligungen nach Doc 20. |
