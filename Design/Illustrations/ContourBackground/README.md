# Fundal — Contururi native

Varianta vizuală aleasă rămâne 04, Contururi mari (`selected-variant-04.png`).

Aplicația desenează acum ilustrațiile direct, cu trasee SwiftUI/Core Graphics. `HomeContourDrawing.swift` conține traseele sacului de bani, monedelor, cardului, sacoșei, bonului, calendarului și săgeților recurente. Nu folosește sprite sheets sau imagini pentru fundal.

Traseele se dezvăluie progresiv la prima afișare, timp de aproximativ două secunde, cu un mic decalaj între linii. Desenele rămân complete la derulare și după revenirea din detalii. Reduce Motion afișează direct contururile complete. Poziționarea urmează ancorele secțiunilor; stratul decorativ ignoră atingerea și VoiceOver.

PNG-urile și prompturile anterioare sunt păstrate numai ca referințe de design în `ArchivedRaster` și `generation-prompts.json`; nu sunt incluse în resursele aplicației.

Toate traseele și liniile de legătură folosesc aceeași culoare opacă. Întregul strat este compus într-un singur grup, apoi primește 25% opacitate. Intersecțiile păstrează aceeași nuanță ca restul liniilor; animația de trasare rămâne activă.
