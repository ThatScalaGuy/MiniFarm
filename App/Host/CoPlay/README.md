# Gemeinsam tragen (iPad)

In der Hofpause öffnet **Gemeinsam tragen** die Partnerwahl. Das erste
Tier bleibt Gastgeber. Ein anderes lokales Tier oder die graue Elternhand
übernimmt die Raute. Die Rollen gelten nur für diese Runde; das Gerät
erkennt keine Personen. Der Solohof bleibt pausiert und gemountet.

- Ein Korb für Keimlinge, zwei für Sprosse, drei für Blüten. Es gilt die
  niedrigere aktuelle Stufe, einschließlich der Stufenwahl der Eltern.
- Der erste Kontakt am jeweiligen Griff bleibt seinem Kreis oder seiner
  Raute zugeordnet, auch wenn die Finger sich kreuzen. Passendes Ziel
  erreichen und loslassen, oder erst Griff, dann Ziel antippen. Abgelegte
  Seiten warten ohne Zeitlimit aufeinander. VoiceOver bietet beide Griffe
  einzeln an. Zusätzliche Finger, Handballen und abgebrochene Züge bringen
  keinen Fortschritt.
- Nur auf Hardware existiert eine gemessene Kontaktfläche. Dort werden
  Kontakte mit einem sicher über 28 pt liegenden Radius verworfen. Der
  A16-Simulator meldet selbst für den einzelnen XCTest-Finger konstant
  31,9 pt; dort entfällt nur die Flächenmessung. Identität, Zonen,
  Abbruch, Ziehen, Ablegen und Sichern nutzen denselben Pfad.
- Erst eine fertige Runde zählt als freies Spiel. Der Gastgeber erhält
  höchstens einen Viertelschritt zur Tagessonne pro Hoftag. Waren, Geld,
  offene Wünsche und der aktuelle Arbeitsschritt ändern sich nicht.
- Bei eingeschalteter Adaptivität zählt eine Zuordnungsübung je
  beteiligtem Kind, nicht pro Berührung oder pro Korb. Die graue Hand
  erzeugt keine zusätzliche Beobachtung. Abbrechen vor der gemeinsamen
  Lieferung schreibt nichts.
- Ein Gast schreibt ausschließlich den atomaren Profilspeicher-Slot
  `BasketPractice`. Er enthält seinen aktualisierten `FarmSkills`-Stand,
  eine laufende Nummer und die letzte Runden-ID, keine Berührungsdaten.
  Die Elternansicht berücksichtigt ihn sofort. Erst beim eigenen
  Hofstart wird ein neuerer Stand einmalig in `Farm` übernommen. Dies
  ändert bei einem Besuch weder `Farm.json` noch dessen Sicherung oder
  Speicherdatum. Die bestehenden Lösch- und Resetpfade entfernen den Slot.
- Die beiden Profile sind keine verteilte Transaktion: Zuerst wird
  die Übung des Gasts, dann der Hof des Gastgebers gesichert. Ein
  Schreibfehler ist sichtbar; erneutes Sichern derselben Runde vergibt
  nichts doppelt. Bei Prozessabbruch dazwischen bleibt die tatsächlich
  ausgeführte Gastübung erhalten, ohne zusätzliche Hofgutschrift.
