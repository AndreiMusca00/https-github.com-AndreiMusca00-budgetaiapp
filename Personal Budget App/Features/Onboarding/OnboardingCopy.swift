struct OnboardingCopy {
    let language: BudgetLanguage
    private var isRomanian: Bool { language == .romanian }

    var languageTitle: String { isRomanian ? "În ce limbă\nvorbim?" : "Let's speak\nyour language." }
    var languageSubtitle: String { isRomanian ? "Alege limba aplicației." : "Choose your app language." }
    var currencyTitle: String { isRomanian ? "Banii tăi.\nMoneda ta." : "Your money.\nYour currency." }
    var currencySubtitle: String { isRomanian ? "Cum vrei să vezi sumele?" : "How would you like to see your amounts?" }
    var languageLabel: String { isRomanian ? "LIMBĂ" : "LANGUAGE" }
    var currencyLabel: String { isRomanian ? "MONEDĂ" : "CURRENCY" }
    var detectedLanguage: String { isRomanian ? "Aleasă după limba telefonului." : "Matched to your phone's language." }
    var changeLater: String { isRomanian ? "Poți schimba mai târziu." : "You can change this later." }
    var continueTitle: String { isRomanian ? "Continuă" : "Continue" }
    var finishTitle: String { isRomanian ? "Să începem" : "Let's start" }
    var backTitle: String { isRomanian ? "Înapoi" : "Back" }
    var chooseLanguage: String { isRomanian ? "Alege țara" : "Choose a country" }
    var chooseCurrency: String { isRomanian ? "Alege moneda" : "Choose a currency" }
    var search: String { isRomanian ? "Caută" : "Search" }
    var close: String { isRomanian ? "Închide" : "Close" }
    var retry: String { isRomanian ? "Încearcă din nou" : "Try again" }
    var unavailable: String { isRomanian ? "Limbile pentru dictare nu sunt disponibile momentan." : "Dictation languages are temporarily unavailable." }
    var saveError: String { isRomanian ? "Nu am putut salva. Încearcă din nou." : "Couldn't save your choices. Please try again." }
}
