# Personal Budget App

Aplicație iPhone nativă, manuală și offline, cu SwiftUI, Observation și SwiftData. Tema este negru-verde. Dictarea, AI și importul Wallet sunt amânate; codul experimental Speech este păstrat, dar nu este accesibil din interfață.

## Structură

    Personal Budget App/
    ├── App/                          # Bootstrap, taburi și bannerul de anulare
    ├── Core/
    │   ├── Ledger/                   # Conturi, tranzacții, recurențe, bugete, calcule, migrare
    │   ├── Expenses/                 # Modelul vechi păstrat pentru migrare; sume exacte
    │   ├── Categories/               # Categorii pentru cheltuieli și venituri
    │   ├── Persistence/              # Container SwiftData local
    │   ├── Preferences/              # Monedă și limbă, UserDefaults
    │   ├── Currency/                 # Catalog ISO și formatare
    │   ├── Navigation/               # Intrări manuale din widget
    │   └── Speech/                   # Experimentul vocal, inaccesibil în versiunea manuală
    ├── DesignSystem/                 # Culori, componente și texte RO/EN
    └── Features/
        ├── Home/                     # Cerc de buget, categorii fluide și detalii la tap
        ├── Transactions/             # Editor și istoric cu căutare/filtre
        ├── Accounts/                 # Creare, editare, arhivare, sold inițial
        ├── Recurring/                # Planificare, confirmare, omitere și pauză
        ├── Budgets/                  # Limite lunare separate pe monede
        ├── Categories/               # Administrare și selector cu emoji Apple
        ├── Onboarding/               # Limbă → monedă, fără dependență de Speech
        └── Preferences/              # Setări și preferințe
    BudgetQuickAdd/                   # Widget mic/mediu: Cheltuială și Venit
    BudgetUITests/                    # Fluxuri complete, cu date în memorie izolate
    Tests/                            # Verificări financiare și schema prototipului
    Scripts/                          # Verificări reproductibile

## Date și calcule

- BudgetAccount: nume, emoji, cod ISO, sold inițial exact, cont implicit și arhivare.
- LedgerEntry: tip cheltuială/venit/transfer, cont, sumă exactă, dată, categorie, descriere și notiță. Transferurile au cont destinație și sumă primită.
- MonthlyBudget: limită pentru o lună calendaristică și o monedă, cu `categoryID` opțional. `nil` păstrează bugetul general existent; un ID identifică limita unei categorii de cheltuieli. Veniturile nu setează automat bugetul. Limitele pe categorii sunt sub-limite independente, nu sume adăugate la plafonul general. Ecranul de planificare arată totalul alocat și diferența față de plafon, inclusiv supralocarea. Limitele nu se copiază automat în lunile următoare. Ștergerea unei categorii elimină limitele ei fără să modifice istoricul sau bugetul general.
- RecurrenceRule: sumă estimată, cont, categorie, frecvență săptămânală/lunară/anuală, interval, ancoră calendaristică, scadență, sfârșit opțional și pauză.
- ExpenseCategory: categorii separate pentru cheltuieli și venituri, cu emoji de sistem și nume personalizabile.

Sumele sunt Int64 în unități monetare minime, cu precizia monedei păstrată lângă sumă. Calculele folosesc Decimal; Double este folosit doar la desenarea progresului. Monedele diferite nu sunt însumate implicit.

Soldul unui cont este soldul inițial plus veniturile confirmate, minus cheltuielile confirmate și transferurile trimise, plus transferurile primite. Soldul inițial este valoarea înaintea tranzacțiilor urmărite aici.

Transferurile nu intră în totalul veniturilor sau cheltuielilor. La transferuri între valute diferite se introduce explicit suma primită, fără curs de schimb presupus. Editarea, ștergerea și anularea unui transfer modifică ambele conturi prin aceeași înregistrare.

Un cont cu tranzacții sau recurențe se arhivează; nu poate fi șters și nu își poate schimba moneda. Arhivarea păstrează istoricul și soldul, inclusiv în totalurile pe monedă. Conturile nefolosite pot fi șterse.

## Home și cercul interactiv

Home folosește o interfață deschisă, inspirată de Notes: luna, suma cheltuită, disponibilul din buget, două butoane Liquid Glass către Tranzacții și Categorii și un singur buton de adăugare discret. Sus există două controale distincte: meniul cu trei puncte pentru bugete, conturi și monedă, plus butonul separat pentru Setări. Tipografia este rotunjită și puțin mai groasă. Nu mai există tab bar sau cerc de buget. „De verificat” arată toate propunerile neconfirmate, inclusiv cele din alte perioade, fără a le include în solduri sau bugete.

Încasările lunii sunt afișate discret pe Home și deschid un istoric filtrat după venituri, cu totalul aferent selecției. Sunt agregate conturile în aceeași monedă; transferurile și propunerile neconfirmate nu sunt venituri, iar bugetul nu se modifică automat când este înregistrat un salariu. Resetarea filtrelor în acest ecran păstrează tipul „Venit”.

Formularul de tranzacție se deschide pe tot ecranul, cu X în stânga sus, salvare prin bifă în dreapta sus și selectorul Cheltuială / Venit / Transfer. La adăugare, tastatura se deschide direct pe sumă. Suma și descrierea obligatorie sunt pe același rând; dedesubt sunt selectoarele compacte pentru categorie, cont și data implicită Azi, cu calendar la atingere. Butoanele își iau lățimea din text și se reașază pe două rânduri când numele este lung, fără prescurtare cu puncte. Categoria, contul și frecvența folosesc UIPickerView, iar data UIDatePicker cu rotițe, în locul tastaturii. Selecțiile se aplică direct, fără Gata sau salvare la baza ecranului; atingerea sumei/descrierii readuce tastatura. Destinația unui transfer exclude sursa și pornește pe primul cont disponibil. Tranzacțiile noi de tip cheltuială/venit au un comutator Recurentă, implicit oprit; activarea alege Lunar și permite Săptămânal/Lunar/Anual. Salvarea înregistrează plata curentă și programează următoarea scadență, iar Anulează elimină și noua recurență. Nu există secțiune Detalii în formularul manual. Transferurile au cont sursă/destinație și cer suma primită când monedele diferă. Notele existente rămân în date; recurențele existente se gestionează în ecranul dedicat. Descrierea este validată atât la activarea butonului, cât și la salvarea manuală.

Navigarea folosește un singur NavigationStack; luna și moneda sunt context comun în LedgerSession, păstrat între Home, categorii și istoricul filtrat. Istoricul este o listă simplă pe zile, cu căutare la cerere și filtre după tip, cont, categorie (inclusiv etichetele istorice), monedă și toate lunile. Fiecare sumă indică moneda; transferurile între monede păstrează și suma primită. Editarea, ștergerea și confirmarea propunerilor folosesc salvare directă și Anulează.

Categorii arată cheltuit / buget și o linie fină de progres. Tap pe o categorie afișează exclusiv cheltuielile confirmate ale acesteia în luna și moneda selectate. Categoriile fără cheltuieli și fără limită sunt grupate discret, iar istoricul categoriilor șterse rămâne separat. Editarea bugetelor și managerul de categorii sunt accesibile din acest ecran. Tranzițiile native de navigare, schimbarea numerelor și actualizarea listelor respectă Reduce Motion. Liquid Glass este rezervat controalelor, iar ecranele de editare folosesc suprafețe discrete.


Datele demonstrative pentru verificarea interfeței sunt disponibile exclusiv în Debug, cu argumentul `-budget-notes-tests` (sau `-budget-orbit-tests` fără limitele pe categorii), în baza izolată în memorie. Pornirea normală utilizează datele locale existente.

## Salvare și Anulează

Introducerea manuală salvează direct o tranzacție confirmată. Bannerul oferă Anulează timp de 8 secunde. Editarea și ștergerea au același mecanism; anularea restabilește valorile exacte, identificatorul și datele originale.

Se poate anula ultima operație disponibilă în banner. O nouă operație înlocuiește acțiunea precedentă. În caz de eroare la salvare, contextul este readus la ultima stare salvată.

## Recurențe

Regulile reprezintă intenții viitoare, separate de tranzacțiile efective. Crearea unei reguli nu modifică soldurile sau bugetul. Confirmarea unei scadențe creează o tranzacție reală și avansează regula; suma și data efectivă pot fi corectate înainte de confirmare.

Omiterea unei scadențe avansează regula fără tranzacție. Confirmarea și omiterea se pot anula. Un identificator de apariție împiedică dublarea aceleiași scadențe.

Regulile lunare păstrează ancora: 31 ianuarie → 28/29 februarie → 31 martie. Există și „Ultima zi a lunii”. Pauza și ștergerea regulii nu șterg tranzacțiile trecute.

Scadențele sunt calculate la accesarea datelor. Această versiune nu promite execuție în fundal la o oră exactă și nu trimite notificări programate.

## Migrarea prototipului

Modelele originale Expense, ExpenseCategory și BudgetMetadata rămân în schemă pentru o actualizare aditivă. La prima pornire, cheltuielile vechi sunt copiate în LedgerEntry cu aceiași identificatori și valori și primesc conturi separate pe monede, cu sold inițial zero.

Un marker persistent face migrarea idempotentă. Propunerile vechi rămân de verificat și sunt accesibile din Setări → De verificat; nu intră în totaluri până la salvare. Categoriile șterse nu sunt reintroduse. Ștergerea unei categorii păstrează numele/emoji-ul în istoric.

Nu se înlocuiește o bază care nu poate fi deschisă cu o bază goală în memorie. Se afișează reîncercarea.

## Limbă și widget

Onboarding și setări oferă română și engleză independent de catalogul Apple Speech. Preferințele noi au appLanguageCode; preferințele vechi rămân decodabile. Textele interfeței și formatarea urmează alegerea din aplicație.

Widgetul oferă intrări manuale pentru cheltuieli și venituri. URL-urile acceptate sunt personalbudget://add/manual, personalbudget://add/income și personalbudget://add/transfer. Ruta voice este ignorată. Nu există acces la microfon în fluxurile active.

SwiftData este local, fără CloudKit sau cont obligatoriu. Nu există conexiune bancară și soldurile sunt calculate din datele introduse.

## Verificări

    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./Scripts/check-orbit.sh
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./Scripts/check-ledger.sh
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./Scripts/check-preferences.sh
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./Scripts/check-expenses.sh
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
      -project 'Personal Budget App.xcodeproj' -scheme 'Personal Budget App' \
      -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
      CODE_SIGNING_ALLOWED=NO test

check-ledger creează baze cu schema originală și cu schema de dinaintea limitelor pe categorii, în executabile separate, apoi verifică migrarea, bugetele existente, limitele pe categorii și redeschiderea. Restul verificărilor acoperă precizia, solduri, transferuri, Undo, editare/ștergere, recurențe și bugete.

Testele UI folosesc preferințe izolate și o bază în memorie, fără a șterge datele obișnuite. Ele verifică introducerea directă, Undo, conturi, venituri, transferuri, recurențe, categorii, bugete, limba engleză și URL-urile widgetului.


Home arată Încasări deasupra Cheltuielilor, în două carduri Liquid Glass, cu progresul bugetului în cardul de cheltuieli, fiecare cu istoric filtrat. Propunerile de verificat apar într-un carusel Liquid Glass între lună și totaluri; când nu există, caruselul și spațiul lui dispar. Mesajul Totul e la zi a fost eliminat din Home. Microfonul plutește deasupra adăugării manuale, cu aceeași dimensiune și suprafață.

Dictarea folosește controllerul Apple existent și afișează cuvintele live peste Home. Stop finalizează transcrierea și creează o propunere locală neconfirmată; X anulează fără să salveze. În acest MVP textul este păstrat integral, iar suma/categoria se completează la verificare, înainte de includerea în buget sau solduri. Refuzul permisiunilor și lipsa serviciului sunt afișate în overlay. Testele de flux folosesc exclusiv în Debug o transcriere injectată, fără accesarea microfonului.

Debug: `-budget-home-review-examples` adaugă o singură dată trei propuneri etichetate Exemplu în baza persistentă normală, fără a reseta datele existente. Acest argument nu este un flag pentru baza în memorie. Meniul Șterge exemplele elimină doar înregistrările cu sursa `demo.home.*`, inclusiv cele confirmate, și oferă Anulează. `-budget-review-tests` și `-budget-voice-tests` sunt separat izolate în memorie pentru verificări automate.


Cardurile pending au trei acțiuni separate: atingerea conținutului deschide editarea, bifa confirmă direct, iar X respinge cu Anulează. Confirmarea și respingerea reîncarcă înregistrarea după ID și verifică starea pending, astfel încât atingerile repetate nu dublează sume și nu șterg tranzacții deja confirmate. Datele incomplete sau incompatibile cu contul deschid corectarea. Confirmarea validează și moneda/frecvența zecimală a conturilor, înainte de reutilizarea regulilor din LedgerRepository. Istoricul are sus butoanele Toate / Cheltuieli / Încasări / Transferuri, cu selecție Liquid Glass animată; filtrele avansate rămân la cerere.


Home: cardul Încasări apare primul, urmat de Cheltuieli. Progresul bugetului folosește limita generală pentru luna/moneda curentă, arată procentul real și se colorează portocaliu când este depășit; arcul este plafonat la 100%, fără a limita procentul afișat. Fără buget, apare Setează bugetul. În același card, graficul orizontal reutilizează CategorySpendingSummary, păstrează doar categoriile cu cheltuieli confirmate pozitive și le afișează descrescător. Veniturile, transferurile, propunerile pending, alte luni/monede și categoriile doar bugetate nu generează coloane. Categoriile istorice, șterse sau necategorizate păstrează eticheta lor; atingerea unei coloane deschide istoricul filtrat. Lipsa cheltuielilor ascunde complet graficul.

Home compact: butoanele Tranzacții/Categorii sunt în meniul cu trei puncte. Totalurile deschid în continuare istoricul filtrat. Graficul descrescător, cu coloane la 68 pt între centre, este în cardul Cheltuieli și se derulează în interiorul lui. Bugetul are un grafic circular la dreapta sumei, procent real și limita dedesubt; atingerea lui deschide editarea. Fără buget apare un cerc cu plus, fără progres inventat.

Home focus: atingerea totalului Cheltuieli sau a unei coloane schimbă conținutul în același Home, fără NavigationLink. Suprafața cardului, suma, numele și emoji-ul folosesc matched geometry cu spring discret; restul se retrage prin fade și o scalare mică. Sub rezumat apar tranzacțiile confirmate, filtrate pe aceeași lună/monedă/categorie, grupate pe zile. Editarea folosește formularul existent, iar sumele se actualizează live. Rândurile păstrează EntryRecord pentru eliminări animate sigure. Luna și X-ul rămân accesibile sus; X revine la dashboard. Reduce Motion dezactivează deplasarea animată.

Motion v2: cardul Cheltuieli își păstrează identitatea în ambele stări; aceeași suprafață se repoziționează și se redimensionează cu spring de 0,72 s. Contextul se retrage cu blur/fade scurt, iar rândurile apar în cascadă. LetterBounceRenderer animă glyph-urile dintr-un Text nativ, cu offset, scalare elastică și blur scurt, fără Text separat pentru fiecare literă și fără task-uri per literă. Titlul/suma/numărul și numele tranzacțiilor au un reveal limitat la apariție; editările folosesc numericText. Dictarea reutilizează desenarea elastică doar pe marginea de text nou, păstrând ipotezele deja afișate. Reduce Motion afișează direct starea finală. Referințe: WWDC24/10151 și WWDC25/323; timingul este ajustat după filmarea MonAi furnizată de utilizator.

Motion final: materialul Glass este aplicat direct pe cardul persistent pentru a păstra corect ordinea straturilor în animație. Conținutul vechi dispare în 0,12 s și este decupat în interiorul cardului. Emoji-ul apare elastic pe loc, înaintea literelor, fără să traverseze suma. Reveal-ul așteaptă primul cadru (24 ms) printr-un task anulabil la nivel de text, nu per literă.

Home category columns: graficul ocupă toată lățimea cardului fără padding lateral sau inferior. Coloanele sunt Rectangle de 64 pt, cu spațiu de 4 pt și culoare neutră. Statusul folosește numai bugetul propriu al categoriei pentru luna și moneda afișate: sub 80% neutru, 80–100% avertizare portocalie, peste 100% roșu cu semn de exclamare. Comparația se face exact în Decimal. Fără limită validă nu apar alerte. Marcajele mici sunt așezate deasupra coloanei dacă nu ar încăpea în ea, iar VoiceOver anunță starea și suma rămasă/depășită. Conturile și cardul Încasări nu au fost modificate în această iterație.

Home accounts/income: totalul conturilor active este grupat pe monede, cu moneda aleasă ca sumă principală și celelalte separat. Cardurile orizontale arată soldul actual (deschidere + încasări - cheltuieli ± transferuri confirmate) și cheltuielile din luna selectată. Atingerea cardului deschide istoricul filtrat pe cont, inclusiv transferurile în altă monedă. Încasările din lateral folosesc aceeași prezentare în Home ca cheltuielile, filtrată pe luna/moneda selectate, cu editare/Undo. Coloanele au colțuri de 7 pt și Liquid Glass, păstrează doar emoji-ul vizual și pulsează lent pentru warning/depășire; Reduce Motion/ieșirea din ecran opresc pulsația. În detaliile cheltuielii apare bugetul editabil și starea; suprafața este portocalie/roșie la 30% când e cazul. Zona pentru chirie/abonamente rămâne la stadiul de propuneri vizuale în această iterație.

Home payment calendar: secțiuni distincte pentru Conturi, Cheltuieli și Calendarul plăților. Calendarul este orizontal, filtrat după luna/moneda selectate. PaymentCalendarProjection calculează aparițiile viitoare din recurențe fără a crea tranzacții și păstrează aparițiile confirmate după avansarea regulii. Sunt respectate intervalul, sfârșitul programării, lunile scurte și fusul orar. Atingerea cardului editează regula; Gestionează deschide managerul existent; meniul contextual permite confirmarea doar pentru scadența curentă ajunsă la termen. Cardurile de plată afișează descrierea utilizatorului lângă emoji-ul categoriei. Mini-calendarul afișează zilele rămase pentru scadențele la 0–3 zile și data în rest. Nu există logo-uri de servicii sau eticheta Exemplu. Cele înregistrate sunt verzi și sortate la final; cele scadente azi, mâine sau peste două zile sunt galbene, în zile calendaristice ale regulii. Plățile mai vechi neconfirmate rămân De înregistrat. Filtrarea păstrează numai aparițiile lunii alese, inclusiv cele înregistrate. `-budget-payment-calendar-examples` adaugă o singură dată patru reguli lunare demo: Chirie, Netflix, iCloud, Spotify. Nu creează cheltuieli și nu modifică soldurile. Șterge exemplele din calendar elimină numai ID-urile demo și plățile legate de acestea, cu Undo; markerul rămâne pentru a respecta eliminarea făcută de utilizator. `-budget-payment-calendar-tests` rămâne izolat în memorie.

Home — varianta 1: totaluri direct pe fundal, conturi compacte cu emoji și sold, încasări la dreapta, cheltuieli fără container, grafic cu emoji de categorii și calendar orizontal cu carduri individuale Liquid Glass. Calendarul pune descrierea utilizatorului în titlu, lângă emoji-ul categoriei, și data sau zilele rămase într-o mini-iconiță de calendar. Bugetul general rămâne un cerc de sticlă; arcul se umple 1,1 secunde, apoi o undă verde parcurge exclusiv segmentul completat la fiecare 3,2 secunde. Animațiile continue sunt suspendate în fundal, la ieșirea din zona vizibilă și cu Reduce Motion. Pragul pentru avertizare și sortarea plăților înregistrate la final rămân active. Streaming, Aplicații și cloud, Telefon și internet sunt adăugate o singură dată, inclusiv pe instalările existente; se păstrează ștergerile și categoriile custom cu același nume. Cele trei reguli demo de abonament sunt reclasificate numai dacă încă au categoria generală originală.

Home — fundal Varianta 04: contururi monocrome native SwiftUI, animate la prima afișare. PNG-urile vechi sunt arhivate în Design și nu sunt resurse ale aplicației. Poziționarea folosește ancorele secțiunilor și urmează derularea; la focalizare fundalul dispare. Fundalul nu schimbă dimensiunea conținutului și nu interceptează atingeri. Referința aleasă și prompturile exacte sunt păstrate în Design/Illustrations/ContourBackground.

Contururi native: fundalul Home este desenat integral cu trasee SwiftUI/Core Graphics, cu animație de trasare la prima afișare și suport Reduce Motion. PNG-urile vechi sunt arhivate în Design, în afara catalogului aplicației. Cardurile recurente pun descrierea utilizatorului lângă emoji-ul categoriei; pentru plăți neînregistrate la 0–3 zile, mini-calendarul afișează Azi/Mâine/2 zile/3 zile în limba aplicației. Plățile înregistrate păstrează data și au o bifă mare, estompată lateral; cele apropiate păstrează accentul galben și un ceas discret. Pragul de avertizare rămâne 0–2 zile, iar cele înregistrate sunt grupate la final.

Probă UI — scadență în notch: cardurile recurente au un notch transparent Liquid Glass, cu text adaptiv pentru contrast, lipit de marginea superioară, cu umeri curbați ca vechiul notch iPhone. În ea apare data scurtă (de exemplu 26 dec.) sau Azi/Mâine/2 zile/3 zile pentru scadențe apropiate. Starea rămâne sub sumă, iar bifa/ceasul de fundal, Liquid Glass și sortarea plăților înregistrate la final sunt păstrate. Eticheta datei rămâne completă în VoiceOver, iar notch-ul nu interceptează atingerea cardului.

Home focus — bugete și conturi: detaliile unei categorii reutilizează cercul Liquid Glass din Home, în dreapta sumei, cu procent real și limita dedesubt. Fără limită apare plus și Setează bugetul; atingerea editează exclusiv bugetul categoriei/lunii/monedei selectate. Arcul se încarcă lin și pulsează discret; avertizarea este portocalie, depășirea roșie. Reduce Motion oprește animațiile.

Conturile se deschid în același Home: emoji, nume, sold actual și cheltuieli pentru luna aleasă. Selectorul Toate/Cheltuieli/Încasări/Transferuri este comun cu istoricul. AccountActivity filtrează doar înregistrările confirmate ale contului și lunii, include ambele părți ale transferurilor și folosește suma/moneda primită în contul destinație. Soldul actual și cheltuielile lunii nu se schimbă la filtrare. Editarea și Anulează refolosesc fluxul existent.

Dictare — apariție din exterior spre interior: mesh-ul existent intră de la toate marginile ecranului printr-o mască cu contur curbat și estompat, în 1,2 secunde; controalele apar discret după începutul mișcării. Home rămâne vizibil dedesubt. Reduce Motion afișează direct starea finală.

Detalii categorie — simplificare: cercul de buget este ridicat cu 14 pt și afișează dedesubt numai suma rămasă sau depășirea, fără limita totală și fără rândul separat de avertizare. Culoarea și procentul păstrează starea, iar VoiceOver anunță în continuare avertizarea. Totalul are un simbol de direcție în sticlă, numărul de tranzacții un simbol de listă, iar rândurile au emoji/simboluri aliniate pe suporturi Liquid Glass discrete. Cercul din Home rămâne cu limita totală.
