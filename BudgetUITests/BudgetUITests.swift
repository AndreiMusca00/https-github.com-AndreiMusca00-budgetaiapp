import XCTest

final class BudgetUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testNotesHomeDirectSaveUndoEditDeleteAndBudget() throws {
        let app = launch()
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertTrue(app.buttons["home.settings"].exists)
        XCTAssertLessThanOrEqual(app.buttons["home.menu"].frame.maxX, app.buttons["home.settings"].frame.minX)
        XCTAssertTrue(app.buttons["ledger.add"].isHittable)
        XCTAssertLessThanOrEqual(app.buttons["ledger.add"].frame.maxY, app.frame.maxY - 24)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "home.orbit").firstMatch.exists)
        add(app, kind: "Cheltuială", amount: "100", name: "Magazin")
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("100"))
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("0,00"))
        add(app, kind: "Cheltuială", amount: "100", name: "Magazin")
        openHome("home.transactions", app)
        XCTAssertTrue(row("Magazin", app).waitForExistence(timeout: 5))
        row("Magazin", app).tap()
        XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 5))
        replace(app.textFields["entry.amount"], with: "125")
        attach("03-notes-entry-editor", app)
        app.buttons["entry.save"].tap()
        XCTAssertTrue(row("Magazin", app).waitForExistence(timeout: 5))
        XCTAssertTrue(row("Magazin", app).label.contains("125"))
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(row("Magazin", app).label.contains("100"))
        row("Magazin", app).tap()
        app.buttons["entry.delete"].tap(); app.sheets.buttons["Șterge"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(row("Magazin", app).waitForExistence(timeout: 5))
        home(app)
        menu("Buget lunar", app)
        let amount = app.textFields["budget.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5)); amount.tap(); amount.typeText("500")
        app.buttons["budget.save"].tap()
        XCTAssertTrue(app.staticTexts["home.remaining"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.remaining"].label.contains("400"))
        XCTAssertFalse(app.staticTexts["home.upToDate"].exists)
        attach("01-notes-home", app)
    }

    @MainActor func testHomeGlassCardsBudgetAndCategoryChart() throws {
        let app = launch("-budget-chart-tests")
        XCTAssertTrue(app.staticTexts["home.received"].label.contains("6.000"))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("1.850"))
        XCTAssertLessThan(app.staticTexts["home.received"].frame.maxY, app.staticTexts["home.spent"].frame.minY)
        XCTAssertFalse(app.buttons["home.transactions"].exists)
        XCTAssertFalse(app.buttons["home.categories"].exists)
        XCTAssertFalse(app.progressIndicators["home.budget.progress"].exists)
        let budget = app.buttons["home.budget"]
        XCTAssertTrue((budget.value as? String ?? "").contains("46"))
        XCTAssertGreaterThan(budget.frame.minX, app.staticTexts["home.spent"].frame.maxX)
        attach("90-glass-income-and-spending-cards", app)
        revealCategoryChart(app)
        let bars = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.chart.category."))
        XCTAssertEqual(bars.count, 6)
        let labels = bars.allElementsBoundByIndex.map(\.label)
        for (index, amount) in ["720", "540", "360", "180", "30", "20"].enumerated() { XCTAssertTrue(labels[index].contains(amount)) }
        XCTAssertFalse(labels.contains { $0.contains("Sănătate") || $0.contains("Salariu") })
        XCTAssertFalse(app.scrollViews["home.categoryChart"].staticTexts["Cumpărături"].exists)

        attach("91-category-chart-descending", app)
        let card = app.descendants(matching: .any).matching(identifier: "home.expenses.overview").firstMatch
        let chartFrame = app.scrollViews["home.categoryChart"].frame
        XCTAssertTrue(card.frame.insetBy(dx: -1, dy: -1).contains(chartFrame), "Card: \(card.frame), chart: \(chartFrame)")
        XCTAssertEqual(chartFrame.minX, card.frame.minX, accuracy: 1)
        XCTAssertEqual(chartFrame.maxX, card.frame.maxX, accuracy: 1)
        XCTAssertEqual(bars.element(boundBy: 0).frame.minX, chartFrame.minX, accuracy: 1)
        XCTAssertTrue((bars.element(boundBy: 2).value as? String ?? "").contains("Aproape de limită"))
        XCTAssertTrue((bars.element(boundBy: 3).value as? String ?? "").contains("Buget depășit"))
        XCTAssertTrue((bars.element(boundBy: 0).value as? String ?? "").contains("Buget rămas"))
        XCTAssertEqual(bars.element(boundBy: 5).value as? String, "Fără limită stabilită")
        XCTAssertLessThan(bars.element(boundBy: 1).frame.midX - bars.element(boundBy: 0).frame.midX, 72)
        bars.element(boundBy: 2).tap()
        XCTAssertTrue(app.buttons["home.focus.budget"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.focus.budget"].label.contains("450"))
        XCTAssertTrue((app.buttons["home.focus.budget"].value as? String ?? "").contains("80"))
        XCTAssertGreaterThan(app.buttons["home.focus.budget"].frame.minX, app.staticTexts["home.focus.total"].frame.maxX)
        let budgetCaption = app.staticTexts["home.focus.budget.caption"]
        XCTAssertTrue(budgetCaption.label.contains("90 lei rămași"))
        attach("105-warning-category-budget", app)
        home(app); revealCategoryChart(app)
        let leisure = bars.matching(NSPredicate(format: "label BEGINSWITH %@", "Timp liber,")).firstMatch
        let horizontalChart = app.scrollViews["home.categoryChart"]
        for _ in 0..<3 { if leisure.isHittable { break }; horizontalChart.swipeLeft() }
        XCTAssertTrue(leisure.isHittable)
        leisure.tap()
        XCTAssertTrue(row("Timp liber", app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.focus.close"].isHittable)
        XCTAssertFalse(app.navigationBars.buttons.firstMatch.exists)
        XCTAssertFalse(app.buttons["home.income"].exists)
        XCTAssertFalse(app.buttons["home.review"].exists)
        XCTAssertFalse(app.scrollViews["home.categoryChart"].exists)
        XCTAssertEqual(app.staticTexts["home.focus.title"].label, "Timp liber")
        XCTAssertTrue(app.staticTexts["home.focus.total"].label.contains("20"))
        attach("93-category-focus-on-home", app)
        let categoryBudget = app.buttons["home.focus.budget"]
        XCTAssertEqual(categoryBudget.label, "Setează bugetul")
        categoryBudget.tap()
        XCTAssertTrue(app.textFields["budget.amount"].waitForExistence(timeout: 5))
        replace(app.textFields["budget.amount"], with: "100")
        app.buttons["budget.save"].tap()
        XCTAssertTrue(categoryBudget.waitForExistence(timeout: 5))
        XCTAssertTrue(categoryBudget.label.contains("100"))
        XCTAssertTrue((categoryBudget.value as? String ?? "").contains("20"))
        attach("130-category-circular-budget-set", app)
        categoryBudget.tap()
        XCTAssertTrue(app.buttons["budget.remove"].waitForExistence(timeout: 5)); app.buttons["budget.remove"].tap()
        XCTAssertTrue(categoryBudget.waitForExistence(timeout: 5))
        XCTAssertEqual(categoryBudget.label, "Setează bugetul")
        row("Timp liber", app).tap()
        XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 5))
        replace(app.textFields["entry.amount"], with: "25")
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.staticTexts["home.focus.total"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.focus.total"].label.contains("25"))
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(app.staticTexts["home.focus.total"].label.contains("20"))
        row("Timp liber", app).tap()
        XCTAssertTrue(app.buttons["entry.delete"].waitForExistence(timeout: 5))
        app.buttons["entry.delete"].tap(); app.sheets.buttons["Șterge"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "home.focus.empty").firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["home.focus.title"].label, "Timp liber")
        XCTAssertEqual(app.staticTexts["home.focus.total"].label, "0 lei")
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(row("Timp liber", app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.focus.total"].label.contains("20"))
        home(app); revealCategoryChart(app)
        let transport = bars.matching(NSPredicate(format: "label BEGINSWITH %@", "Transport,")).firstMatch
        let chart = app.scrollViews["home.categoryChart"]
        for _ in 0..<3 { if transport.isHittable { break }; chart.swipeLeft() }
        XCTAssertTrue(transport.isHittable); transport.tap()
        XCTAssertTrue(row("Benzină", app).waitForExistence(timeout: 5))
        XCTAssertTrue(row("Parcare", app).exists)
        XCTAssertFalse(row("Transport de verificat", app).exists)
        XCTAssertEqual(app.staticTexts["home.focus.title"].label, "Transport")
        XCTAssertTrue(app.staticTexts["home.focus.total"].label.contains("180"))
        XCTAssertTrue(app.buttons["home.focus.budget"].label.contains("150"))
        XCTAssertTrue(budgetCaption.label.contains("30 lei peste buget"))
        attach("106-exceeded-category-budget", app)
        home(app)
        chooseMonth(Calendar.current.date(byAdding: .month, value: -1, to: .now)!, app)
        revealCategoryChart(app)
        XCTAssertEqual(bars.count, 1)
        XCTAssertTrue(bars.firstMatch.label.contains("50"))
        home(app); chooseMonth(.now, app)
        app.buttons["home.menu"].tap()
        if !app.buttons["EUR"].firstMatch.exists { app.buttons["Moneda"].tap() }
        app.buttons["EUR"].firstMatch.tap()
        revealCategoryChart(app)
        XCTAssertEqual(bars.count, 1)
        XCTAssertTrue(bars.firstMatch.label.contains("250 EUR"))
    }

    @MainActor func testPlainHomeGlassRingAndSubscriptionCategories() throws {
        let app = launch("-budget-payment-calendar-tests")
        let reject = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pending.reject.")).firstMatch
        if reject.waitForExistence(timeout: 4) { reject.tap() }
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "home.accounts.card").firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "home.expenseCard").firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "home.payments.card").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "home.expenses.overview").firstMatch.exists)
        let ring = app.descendants(matching: .any).matching(identifier: "home.budget.ring").firstMatch
        XCTAssertTrue(ring.exists)
        XCTAssertTrue((app.buttons["home.budget"].value as? String ?? "").contains("46"))
        XCTAssertEqual(ring.frame.width, ring.frame.height, accuracy: 1)
        attach("130-plain-home-accounts-category-icons-glass-budget", app)
        let frame = ring.frame
        RunLoop.current.run(until: Date().addingTimeInterval(1.6))
        XCTAssertEqual(ring.frame, frame)
        attach("131-budget-ring-stable-during-green-wave", app)
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.payment."))
        let cloud = cards.matching(NSPredicate(format: "label CONTAINS %@", "iCloud")).firstMatch
        XCTAssertTrue(cloud.label.contains("iCloud"))
        XCTAssertFalse(cloud.label.contains("Aplicații și cloud"))
        let netflix = cards.matching(NSPredicate(format: "label CONTAINS %@", "Netflix")).firstMatch
        XCTAssertTrue(netflix.label.contains("Netflix"))
        XCTAssertFalse(netflix.label.contains("Streaming"))
        menu("Setări", app); app.buttons["settings.categories"].tap()
        for name in ["Streaming", "Aplicații și cloud", "Telefon și internet"] {
            let category = app.buttons["category.edit.\(name)"]
            for _ in 0..<5 { if category.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(category.exists)
        }
        attach("132-three-new-subscription-categories", app)
    }

    @MainActor func testPaymentCalendarWarningRecordedOrderAndUndo() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-budget-payment-calendar-tests", "-budget-payment-status-preview"]
        app.launch()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 8))
        let reject = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pending.reject.")).firstMatch
        if reject.waitForExistence(timeout: 4) { reject.tap() }
        let carousel = app.scrollViews["home.payments.carousel"]
        for _ in 0..<5 {
            if carousel.isHittable && carousel.frame.maxY < app.buttons["ledger.voice"].frame.minY { break }
            app.swipeUp()
        }
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.payment."))
        XCTAssertEqual(cards.count, 4)
        let cloud = cards.matching(NSPredicate(format: "label CONTAINS %@", "iCloud")).firstMatch
        let netflix = cards.matching(NSPredicate(format: "label CONTAINS %@", "Netflix")).firstMatch
        let paid = cards.matching(NSPredicate(format: "label CONTAINS %@", "Spotify")).firstMatch
        XCTAssertEqual(cloud.value as? String, "Scadentă curând")
        XCTAssertEqual(netflix.value as? String, "Scadentă curând")
        XCTAssertEqual(paid.value as? String, "Înregistrată")
        XCTAssertTrue(cloud.label.contains("Azi"))
        XCTAssertTrue(netflix.label.contains("2 zile"))
        let rent = cards.matching(NSPredicate(format: "label CONTAINS %@", "Chirie")).firstMatch
        if Calendar.current.range(of: .day, in: .month, for: .now)!.count - Calendar.current.component(.day, from: .now) >= 3 {
            XCTAssertTrue(rent.label.contains("3 zile"))
        }
        XCTAssertFalse(paid.label.contains("zile"))
        XCTAssertTrue(cards.allElementsBoundByIndex.allSatisfy { !$0.label.contains("Exemplu") })
        let unpaid = cards.allElementsBoundByIndex.filter { ($0.value as? String) != "Înregistrată" }
        XCTAssertGreaterThan(paid.frame.minX, unpaid.map(\.frame.maxX).max()!)
        attach("120-recurring-warning-without-service-icons", app)
        for _ in 0..<3 { if paid.isHittable { break }; carousel.swipeLeft() }
        XCTAssertTrue(paid.isHittable)
        attach("121-recorded-payments-green-at-end", app)
        for _ in 0..<4 { if cloud.isHittable { break }; carousel.swipeRight() }
        XCTAssertTrue(cloud.isHittable)
        cloud.press(forDuration: 0.7)
        app.buttons["Confirmă plata"].tap()
        XCTAssertTrue(app.buttons["entry.save"].waitForExistence(timeout: 5))
        app.buttons["entry.save"].tap()
        let recorded = NSPredicate(format: "value == %@", "Înregistrată")
        expectation(for: recorded, evaluatedWith: cloud)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(cards.count, 4)
        XCTAssertGreaterThan(cloud.frame.minX, netflix.frame.minX)
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 4))
        app.buttons["ledger.undo"].tap()
        XCTAssertEqual(cloud.value as? String, "Scadentă curând")
        let next = Calendar.current.date(byAdding: .month, value: 1, to: .now)!
        chooseMonth(next, app)
        XCTAssertEqual(cards.count, 4)
        XCTAssertTrue(cards.allElementsBoundByIndex.allSatisfy { ($0.value as? String) == "Programată" })
        attach("122-next-month-has-no-carried-recorded-status", app)
        chooseMonth(Calendar.current.date(byAdding: .month, value: -1, to: .now)!, app)
        XCTAssertEqual(cards.count, 0)
    }

    @MainActor func testHomeHorizontalPaymentCalendarAcrossMonths() throws {
        let app = launch("-budget-payment-calendar-tests")
        let reject = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pending.reject.")).firstMatch
        if reject.waitForExistence(timeout: 4) { reject.tap() }
        let accountCard = app.descendants(matching: .any).matching(identifier: "home.accounts.overview").firstMatch
        XCTAssertTrue(accountCard.exists)
        XCTAssertGreaterThanOrEqual(app.buttons["home.income"].frame.minX, accountCard.frame.minX)
        XCTAssertLessThanOrEqual(app.buttons["home.income"].frame.maxX, accountCard.frame.maxX)
        XCTAssertGreaterThanOrEqual(app.scrollViews["home.accounts.carousel"].frame.minY, accountCard.frame.minY)
        XCTAssertLessThanOrEqual(app.scrollViews["home.accounts.carousel"].frame.maxY, accountCard.frame.maxY)
        attach("110-home-three-glass-sections", app)
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.payment."))
        let carousel = app.scrollViews["home.payments.carousel"]
        for _ in 0..<5 {
            if carousel.isHittable && carousel.frame.maxY < app.buttons["ledger.voice"].frame.minY { break }
            app.swipeUp()
        }
        XCTAssertTrue(carousel.isHittable); XCTAssertEqual(cards.count, 4)
        XCTAssertTrue(app.staticTexts["home.payments.total"].label.contains("1.290"))
        let cloud = cards.matching(NSPredicate(format: "label CONTAINS %@", "iCloud")).firstMatch
        let netflix = cards.matching(NSPredicate(format: "label CONTAINS %@", "Netflix")).firstMatch
        XCTAssertEqual(cloud.frame.minY, netflix.frame.minY, accuracy: 2)
        XCTAssertGreaterThan(netflix.frame.minX, cloud.frame.minX)
        attach("111-horizontal-payment-calendar", app)
        let spotify = cards.matching(NSPredicate(format: "label CONTAINS %@", "Spotify")).firstMatch
        for _ in 0..<3 { if spotify.isHittable { break }; carousel.swipeLeft() }
        XCTAssertTrue(spotify.isHittable)
        attach("112-calendar-scroll-to-last-service", app)
        let next = Calendar.current.date(byAdding: .month, value: 1, to: .now)!
        chooseMonth(next, app)
        XCTAssertEqual(cards.count, 4)
        let suffix = ":\(Calendar.current.component(.year, from: next))-\(Calendar.current.component(.month, from: next))-"
        XCTAssertTrue(cards.allElementsBoundByIndex.allSatisfy { $0.identifier.contains(suffix) })
        for _ in 0..<4 { if carousel.isHittable { break }; app.swipeUp() }
        attach("113-recurring-payments-next-month", app)
        for _ in 0..<3 { if cloud.isHittable { break }; carousel.swipeRight() }
        XCTAssertTrue(cloud.isHittable); cloud.tap()
        XCTAssertTrue(app.buttons["rule.save"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["entry.merchant"].value as? String, "iCloud")
        app.buttons["Închide"].tap()
        chooseMonth(.now, app)
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("1.850"))
        XCTAssertTrue(app.staticTexts["home.accounts.total"].label.contains("4.100"))
        openHome("home.income", app)
        XCTAssertTrue(app.staticTexts["home.focus.total"].label.contains("6.000"))
        XCTAssertFalse(carousel.exists)
        home(app)
        app.buttons["home.menu"].tap(); app.buttons["home.clearPaymentExamples"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 4))
        XCTAssertEqual(cards.count, 0)
        app.buttons["ledger.undo"].tap()
        XCTAssertEqual(cards.count, 4)
    }

    @MainActor func testAccountFocusFiltersTransfersEditUndoAndMonth() throws {
        let app = launch("-budget-chart-tests")
        app.buttons["ledger.add"].tap()
        XCTAssertTrue(app.buttons["entry.kind.transfer"].waitForExistence(timeout: 5)); app.buttons["entry.kind.transfer"].tap()
        app.buttons["entry.destination"].tap(); pickInput("Euro", app)
        app.textFields["entry.amount"].tap(); app.textFields["entry.amount"].typeText("100")
        app.textFields["entry.received"].tap(); app.textFields["entry.received"].typeText("20")
        app.textFields["entry.merchant"].tap(); app.textFields["entry.merchant"].typeText("Schimb valutar\n")
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        let accounts = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.account."))
        let personal = accounts.matching(NSPredicate(format: "label CONTAINS %@", "Personal")).firstMatch
        XCTAssertTrue(personal.waitForExistence(timeout: 5)); personal.tap()
        XCTAssertTrue(app.staticTexts["home.accountFocus.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.accountFocus.title"].label.contains("Personal"))
        XCTAssertTrue(app.staticTexts["home.accountFocus.balance"].label.contains("3.900"))
        XCTAssertTrue(app.staticTexts["home.accountFocus.spent"].label.contains("1.850"))
        XCTAssertFalse(app.navigationBars.buttons.firstMatch.exists)
        XCTAssertFalse(app.buttons["home.focus.budget"].exists)
        XCTAssertTrue(app.buttons["home.accountFocus.kind.all"].isSelected)
        app.buttons["home.accountFocus.kind.income"].tap()
        XCTAssertTrue(row("Salariu", app).waitForExistence(timeout: 5)); XCTAssertFalse(row("Schimb valutar", app).exists)
        app.buttons["home.accountFocus.kind.expense"].tap()
        XCTAssertTrue(row("Haine", app).waitForExistence(timeout: 5)); XCTAssertFalse(row("Salariu", app).exists)
        XCTAssertFalse(row("Transport de verificat", app).exists)
        app.buttons["home.accountFocus.kind.transfer"].tap()
        XCTAssertTrue(row("Schimb valutar", app).waitForExistence(timeout: 5))
        XCTAssertTrue(row("Schimb valutar", app).label.contains("−100 lei"))
        XCTAssertTrue(row("Schimb valutar", app).label.contains("→ Euro"))
        XCTAssertFalse(row("Haine", app).exists)
        attach("131-account-outgoing-transfers", app)
        row("Schimb valutar", app).tap()
        XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 5))
        replace(app.textFields["entry.amount"], with: "120"); app.buttons["entry.save"].tap()
        XCTAssertTrue(app.staticTexts["home.accountFocus.balance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.accountFocus.kind.transfer"].isSelected)
        XCTAssertTrue(app.staticTexts["home.accountFocus.balance"].label.contains("3.880"))
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(app.staticTexts["home.accountFocus.balance"].label.contains("3.900"))
        XCTAssertTrue(row("Schimb valutar", app).label.contains("−100 lei"))
        chooseMonth(Calendar.current.date(byAdding: .month, value: -1, to: .now)!, app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "home.focus.empty").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.accountFocus.balance"].label.contains("3.900"))
        XCTAssertTrue(app.staticTexts["home.accountFocus.spent"].label.contains("50 lei"))
        app.buttons["home.accountFocus.kind.all"].tap()
        XCTAssertTrue(row("Transport luna trecută", app).waitForExistence(timeout: 5))
        chooseMonth(.now, app); home(app)
        let cash = accounts.matching(NSPredicate(format: "label CONTAINS %@", "Numerar")).firstMatch
        XCTAssertTrue(cash.isHittable); cash.tap()
        XCTAssertTrue(app.buttons["home.accountFocus.kind.all"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.accountFocus.kind.all"].isSelected)
        app.buttons["home.accountFocus.kind.transfer"].tap()
        XCTAssertTrue(row("", app).waitForExistence(timeout: 5))
        XCTAssertTrue(row("", app).label.contains("+100 lei"))
        home(app)
        let euro = accounts.matching(NSPredicate(format: "label CONTAINS %@", "Euro")).firstMatch
        let carousel = app.scrollViews["home.accounts.carousel"]
        for _ in 0..<3 { if euro.isHittable && euro.frame.midX < app.frame.maxX - 28 { break }; carousel.swipeLeft() }
        XCTAssertTrue(euro.isHittable); euro.tap()
        XCTAssertTrue(app.staticTexts["home.accountFocus.balance"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.accountFocus.balance"].label.contains("230 EUR"))
        XCTAssertTrue(app.staticTexts["home.accountFocus.spent"].label.contains("250 EUR"))
        app.buttons["home.accountFocus.kind.transfer"].tap()
        XCTAssertTrue(row("Schimb valutar", app).waitForExistence(timeout: 5))
        XCTAssertTrue(row("Schimb valutar", app).label.contains("+20 EUR"))
        XCTAssertFalse(row("Transport EUR", app).exists)
        attach("132-account-incoming-foreign-transfer", app)
        home(app)
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("1.850"))
    }

    @MainActor func testHomeAccountsBalanceAndIncomeFocus() throws {
        let app = launch("-budget-chart-tests")
        let reject = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pending.reject.")).firstMatch
        XCTAssertTrue(reject.waitForExistence(timeout: 5)); reject.tap()
        XCTAssertTrue(app.staticTexts["home.accounts.total"].label.contains("4.100"))
        XCTAssertTrue(app.staticTexts["home.accounts.otherCurrencies"].label.contains("250 EUR"))
        let accounts = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.account."))
        XCTAssertEqual(accounts.count, 3)
        let personal = accounts.matching(NSPredicate(format: "label CONTAINS %@", "Personal")).firstMatch
        XCTAssertTrue(personal.label.contains("4.000"))
        XCTAssertTrue((personal.value as? String ?? "").contains("1.850"))
        let cash = accounts.matching(NSPredicate(format: "label CONTAINS %@", "Numerar")).firstMatch
        XCTAssertTrue(cash.label.contains("100 lei"))
        XCTAssertTrue((cash.value as? String ?? "").contains("0 lei"))
        let euro = accounts.matching(NSPredicate(format: "label CONTAINS %@", "Euro")).firstMatch
        let carousel = app.scrollViews["home.accounts.carousel"]
        for _ in 0..<3 { if euro.isHittable && euro.frame.midX < app.frame.maxX - 28 { break }; carousel.swipeLeft() }
        XCTAssertTrue(euro.isHittable); euro.tap()
        XCTAssertTrue(row("Transport EUR", app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("Chirie", app).exists)
        XCTAssertFalse(row("Salariu", app).exists)
        home(app)
        attach("100-home-accounts-and-glass-columns", app)
        openHome("home.income", app)
        XCTAssertTrue(app.staticTexts["home.focus.total"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["home.focus.title"].label, "Încasări")
        XCTAssertTrue(app.staticTexts["home.focus.total"].label.contains("6.000"))
        XCTAssertFalse(app.navigationBars.buttons.firstMatch.exists)
        XCTAssertFalse(app.buttons["home.focus.budget"].exists)
        XCTAssertTrue(row("Salariu", app).exists)
        XCTAssertTrue(row("Salariu", app).label.contains("+6.000"))
        XCTAssertFalse(row("Chirie", app).exists)
        attach("101-income-focus-on-home", app)
        home(app)
        chooseMonth(Calendar.current.date(byAdding: .month, value: -1, to: .now)!, app)
        XCTAssertTrue(app.staticTexts["home.accounts.total"].label.contains("4.100"))
        XCTAssertTrue((personal.value as? String ?? "").contains("50 lei"))
        openHome("home.income", app)
        XCTAssertEqual(app.staticTexts["home.focus.total"].label, "0 lei")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "home.focus.empty").firstMatch.exists)
    }

    @MainActor func testHomeAllExpensesFocusMonthAndReturn() throws {
        let app = launch("-budget-chart-tests")
        openHome("home.expenses", app)
        XCTAssertTrue(app.buttons["home.focus.close"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars.buttons.firstMatch.exists)
        XCTAssertEqual(app.staticTexts["home.focus.title"].label, "Cheltuieli")
        XCTAssertTrue(app.staticTexts["home.focus.total"].label.contains("1.850"))
        XCTAssertTrue(app.staticTexts["home.focus.count"].label.hasPrefix("8 "))
        XCTAssertTrue(row("Timp liber", app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("Salariu", app).exists)
        XCTAssertFalse(row("Transport de verificat", app).exists)
        XCTAssertFalse(app.buttons["home.income"].exists)
        XCTAssertFalse(app.buttons["home.review"].exists)
        attach("94-all-expenses-focus-on-home", app)
        chooseMonth(Calendar.current.date(byAdding: .month, value: 1, to: .now)!, app)
        XCTAssertEqual(app.staticTexts["home.focus.total"].label, "0 lei")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "home.focus.empty").firstMatch.exists)
        XCTAssertTrue(app.buttons["home.focus.close"].isHittable)
        chooseMonth(.now, app)
        XCTAssertTrue(app.staticTexts["home.focus.total"].label.contains("1.850"))
        app.buttons["home.focus.close"].tap()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("1.850"))
        XCTAssertTrue(app.staticTexts["home.received"].label.contains("6.000"))
        XCTAssertTrue(app.buttons["home.review"].exists)
    }

    @MainActor func testHomeBudgetOverLimitAndNoExpenseChart() throws {
        let app = launch("-budget-chart-tests")
        let budget = app.buttons["home.budget"]
        for _ in 0..<4 { if budget.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(budget.isHittable); budget.tap()
        XCTAssertTrue(app.textFields["budget.amount"].waitForExistence(timeout: 5))
        replace(app.textFields["budget.amount"], with: "1000")
        app.buttons["budget.save"].tap()
        XCTAssertTrue(budget.waitForExistence(timeout: 5))
        XCTAssertTrue((budget.value as? String ?? "").contains("185"))
        XCTAssertTrue(app.staticTexts["home.remaining"].label.contains("850"))
        attach("92-over-budget-progress", app)
        chooseMonth(Calendar.current.date(byAdding: .month, value: 1, to: .now)!, app)
        XCTAssertFalse(app.scrollViews["home.categoryChart"].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "home.budget.ring").firstMatch.exists)
        XCTAssertEqual(app.buttons["home.budget"].label, "Setează bugetul")
    }

    @MainActor func testHomeReviewCardsSeparateIncomeAndExpenses() throws {
        let app = launch("-budget-review-tests")
        XCTAssertTrue(app.buttons["home.review"].waitForExistence(timeout: 5))
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.pending."))
        XCTAssertEqual(cards.count, 3)
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("0,00"))
        XCTAssertTrue(app.staticTexts["home.received"].label.contains("0,00"))
        XCTAssertLessThan(app.staticTexts["home.received"].frame.maxY, app.staticTexts["home.spent"].frame.minY)
        XCTAssertLessThan(app.buttons["period.month"].frame.maxY, app.buttons["home.review"].frame.minY)
        XCTAssertLessThan(app.scrollViews["home.pendingCards"].frame.maxY, app.staticTexts["home.spent"].frame.minY)
        let voice = app.buttons["ledger.voice"]; let manual = app.buttons["ledger.add"]
        XCTAssertTrue(voice.isHittable); XCTAssertTrue(manual.isHittable)
        XCTAssertEqual(voice.frame.width, manual.frame.width, accuracy: 1)
        XCTAssertEqual(voice.frame.midX, manual.frame.midX, accuracy: 1)
        XCTAssertLessThan(voice.frame.maxY, manual.frame.minY)
        XCTAssertFalse(app.staticTexts["home.upToDate"].exists)
        attach("70-home-review-cards-and-totals", app)
        let coffee = cards.matching(NSPredicate(format: "label CONTAINS %@", "Cafea")).firstMatch
        XCTAssertTrue(coffee.label.contains("Exemplu")); coffee.tap()
        XCTAssertTrue(app.buttons["entry.save"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["entry.save"].label, "Confirmă")
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        XCTAssertEqual(cards.count, 2)
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("18,00"))
        XCTAssertTrue(app.staticTexts["home.received"].label.contains("0,00"))
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(coffee.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("0,00"))
        app.buttons["home.review"].tap()
        XCTAssertTrue(row("Bonus", app).waitForExistence(timeout: 5))
        row("Bonus", app).tap()
        XCTAssertTrue(app.buttons["entry.save"].waitForExistence(timeout: 5))
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        home(app)
        XCTAssertTrue(app.staticTexts["home.received"].label.contains("750,00"))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("0,00"))
        openHome("home.income", app)
        XCTAssertTrue(row("Bonus", app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.focus.total"].label.contains("750"))
        home(app)
        openHome("home.expenses", app)
        XCTAssertTrue(app.staticTexts["home.focus.total"].waitForExistence(timeout: 5))
        XCTAssertFalse(row("Bonus", app).exists)
    }

    @MainActor func testPendingCardQuickActionsAndCorrection() throws {
        let app = launch("-budget-review-tests")
        XCTAssertTrue(app.buttons["home.review"].waitForExistence(timeout: 5))
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.pending."))
        let coffee = cards.matching(NSPredicate(format: "label CONTAINS %@", "Cafea")).firstMatch
        let id = String(coffee.identifier.dropFirst("home.pending.".count))
        let confirm = app.buttons["pending.confirm." + id]
        let reject = app.buttons["pending.reject." + id]
        XCTAssertTrue(confirm.isHittable); XCTAssertTrue(reject.isHittable)
        attach("80-pending-card-quick-actions", app)
        confirm.tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["entry.amount"].exists)
        XCTAssertTrue(app.buttons["home.settings"].exists)
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("18,00"))
        XCTAssertEqual(cards.count, 2)
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(coffee.waitForExistence(timeout: 5))
        reject.tap()
        XCTAssertTrue(coffee.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("0,00"))
        XCTAssertEqual(cards.count, 2)
        XCTAssertFalse(app.textFields["entry.amount"].exists)
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(coffee.waitForExistence(timeout: 5))
        coffee.tap()
        XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 5))
        replace(app.textFields["entry.amount"], with: "19")
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("19,00"))
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(coffee.waitForExistence(timeout: 5))
        let bonus = cards.matching(NSPredicate(format: "label CONTAINS %@", "Bonus")).firstMatch
        let bonusID = String(bonus.identifier.dropFirst("home.pending.".count))
        let confirmIncome = app.buttons["pending.confirm." + bonusID]
        for _ in 0..<3 {
            if confirmIncome.isHittable { break }
            app.scrollViews["home.pendingCards"].swipeLeft()
        }
        XCTAssertTrue(confirmIncome.isHittable)
        confirmIncome.tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.received"].label.contains("750,00"))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("0,00"))
        attach("81-vertical-spending-and-income", app)
    }

    @MainActor func testHistoryTopTypeButtons() throws {
        let app = launch("-budget-notes-tests")
        openHome("home.transactions", app)
        let all = app.buttons["history.kind.all"]
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        XCTAssertTrue(all.isSelected)
        XCTAssertTrue(row("Salariu", app).exists)
        XCTAssertTrue(row("Chirie", app).exists)
        app.buttons["history.kind.expense"].tap()
        XCTAssertTrue(app.buttons["history.kind.expense"].isSelected)
        XCTAssertTrue(row("Chirie", app).exists)
        XCTAssertFalse(row("Salariu", app).exists)
        app.buttons["history.kind.income"].tap()
        XCTAssertTrue(row("Salariu", app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("Chirie", app).exists)
        app.buttons["history.kind.transfer"].tap()
        XCTAssertFalse(row("Salariu", app).exists)
        XCTAssertFalse(row("Chirie", app).exists)
        XCTAssertTrue(app.buttons["history.kind.transfer"].isSelected)
        app.buttons["history.kind.all"].tap()
        XCTAssertTrue(row("Chirie", app).waitForExistence(timeout: 5))
        attach("82-transaction-top-buttons", app)
    }

    @MainActor func testRemovingHomeExamplesKeepsManualTransactions() throws {
        let app = launch("-budget-review-tests")
        XCTAssertTrue(app.buttons["home.review"].waitForExistence(timeout: 5))
        add(app, kind: "Cheltuială", amount: "42", name: "Tranzacție manuală")
        let before = app.staticTexts["home.spent"].frame.minY
        app.buttons["home.menu"].tap(); app.buttons["home.clearExamples"].tap()
        XCTAssertTrue(app.scrollViews["home.pendingCards"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.review"].exists)
        XCTAssertFalse(app.staticTexts["home.upToDate"].exists)
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("42,00"))
        XCTAssertLessThan(app.staticTexts["home.spent"].frame.minY, before - 100)
        attach("71-home-without-pending", app)
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(app.buttons["home.review"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("42,00"))
        openHome("home.transactions", app)
        XCTAssertTrue(row("Tranzacție manuală", app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("Cafea", app).exists)
    }

    @MainActor func testVoiceCreatesPendingTextAndCanBeCancelled() throws {
        let app = launch("-budget-voice-tests")
        app.buttons["ledger.voice"].tap()
        XCTAssertTrue(app.buttons["dictation.cancel"].waitForExistence(timeout: 5))
        app.buttons["dictation.cancel"].tap()
        XCTAssertTrue(app.buttons["ledger.voice"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.review"].exists)
        app.buttons["ledger.voice"].tap()
        XCTAssertTrue(app.buttons["dictation.stop"].waitForExistence(timeout: 5))
        attach("72-home-speech-overlay", app)
        app.buttons["dictation.stop"].tap()
        XCTAssertTrue(app.buttons["home.review"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("0,00"))
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.pending.")).firstMatch
        XCTAssertTrue(card.label.contains("Verifică suma"))
        let proposalID = String(card.identifier.dropFirst("home.pending.".count))
        app.buttons["pending.confirm." + proposalID].tap()
        XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["entry.save"].isEnabled)
        XCTAssertTrue(app.staticTexts["Am cheltuit 35 de lei pe cafea."].exists)
        app.textFields["entry.amount"].tap(); app.textFields["entry.amount"].typeText("35")
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("35,00"))
        XCTAssertFalse(app.buttons["home.review"].exists)
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(app.buttons["home.review"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("0,00"))
    }

    @MainActor func testCategoryDrilldownMonthCurrencyAndUndo() throws {
        let app = launch("-budget-notes-tests")
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("1.800"))
        XCTAssertTrue(app.staticTexts["home.remaining"].label.contains("2.200"))
        XCTAssertTrue(app.buttons["home.review"].exists)
        attach("10-notes-home-with-review", app)
        openHome("home.categories", app)
        let transport = app.buttons["spending.category.Transport"]
        XCTAssertTrue(transport.waitForExistence(timeout: 5))
        XCTAssertTrue(transport.label.contains("180")); XCTAssertTrue(transport.label.contains("500"))
        attach("11-notes-categories", app)
        transport.tap()
        XCTAssertTrue(row("Benzină", app).waitForExistence(timeout: 5))
        XCTAssertTrue(row("Parcare", app).exists)
        XCTAssertFalse(row("Chirie", app).exists)
        XCTAssertFalse(row("Transport EUR", app).exists)
        XCTAssertFalse(row("Transport luna trecută", app).exists)
        XCTAssertFalse(row("Transport de verificat", app).exists)
        row("Benzină", app).tap()
        XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 5))
        replace(app.textFields["entry.amount"], with: "110"); app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(row("Benzină", app).label.contains("110"))
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(row("Benzină", app).label.contains("100"))
        back(app)
        XCTAssertTrue(transport.waitForExistence(timeout: 5)); XCTAssertTrue(transport.label.contains("180"))
        let previous = Calendar.current.date(byAdding: .month, value: -1, to: .now)!
        chooseMonth(previous, app)
        XCTAssertTrue(transport.waitForExistence(timeout: 5)); XCTAssertTrue(transport.label.contains("50"))
        transport.tap()
        XCTAssertTrue(row("Transport luna trecută", app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("Benzină", app).exists)
        back(app)
        chooseMonth(.now, app)
        app.buttons["categories.menu"].tap()
        if !app.buttons["EUR"].firstMatch.exists { app.buttons["Moneda"].tap() }
        app.buttons["EUR"].firstMatch.tap()
        XCTAssertTrue(transport.waitForExistence(timeout: 5)); XCTAssertTrue(transport.label.contains("250"))
        transport.tap()
        XCTAssertTrue(row("Transport EUR", app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("Benzină", app).exists)
        home(app)
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("250"))
    }

    @MainActor func testCategoryBudgetEditsAndPendingReview() throws {
        let app = launch("-budget-notes-tests")
        openHome("home.categories", app)
        app.buttons["categories.budgets"].tap()
        let row = app.buttons["budgets.category.Transport"]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        let amount = app.textFields["budget.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5)); replace(amount, with: "150")
        app.buttons["budget.save"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5)); XCTAssertTrue(row.label.contains("peste buget"))
        app.buttons["budgets.close"].tap()
        let transport = app.buttons["spending.category.Transport"]
        XCTAssertTrue(transport.waitForExistence(timeout: 5)); XCTAssertTrue(transport.label.contains("150"))
        XCTAssertTrue((transport.value as? String ?? "").contains("peste buget"))
        attach("12-notes-category-over-budget", app)
        home(app)
        XCTAssertTrue(app.staticTexts["home.remaining"].label.contains("2.200"))
        revealCategoryChart(app)
        let homeTransport = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "home.chart.category.", "Transport,")).firstMatch
        XCTAssertTrue((homeTransport.value as? String ?? "").contains("Buget depășit"))
        home(app)
        app.buttons["home.review"].tap()
        let pending = self.row("Transport de verificat", app)
        XCTAssertTrue(pending.waitForExistence(timeout: 5)); pending.tap()
        XCTAssertTrue(app.buttons["entry.save"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["entry.save"].label, "Confirmă")
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "history.empty").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5)); app.buttons["ledger.undo"].tap()
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
        home(app)
        XCTAssertTrue(app.buttons["home.review"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("1.800"))
    }

    @MainActor func testHistorySearchAndFilters() throws {
        let app = launch("-budget-notes-tests")
        openHome("home.transactions", app)
        XCTAssertTrue(row("Chirie", app).waitForExistence(timeout: 5))
        attach("02-notes-transactions", app)
        app.buttons["history.search"].tap()
        let field = app.textFields["history.searchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("Chirie\n")
        XCTAssertTrue(row("Chirie", app).exists); XCTAssertFalse(row("Benzină", app).exists)
        app.buttons["history.closeSearch"].tap()
        app.buttons["history.kind.income"].tap()
        XCTAssertTrue(app.buttons["history.kind.income"].isSelected)
        XCTAssertTrue(row("Salariu", app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("Chirie", app).exists)
        app.buttons["history.kind.all"].tap()
        app.buttons["history.filters"].tap()
        app.buttons["Toate lunile"].tap()
        app.buttons["history.search"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("Transport luna trecută\n")
        XCTAssertTrue(row("Transport luna trecută", app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("Transport EUR", app).exists)
    }

    @MainActor func testCompactManualEntryRequiresDescription() throws {
        let app = launch()
        app.buttons["ledger.add"].tap()
        let amount = app.textFields["entry.amount"]
        let description = app.textFields["entry.merchant"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertLessThan(amount.frame.width, app.frame.width / 2)
        XCTAssertGreaterThanOrEqual(description.frame.minX, amount.frame.maxX)
        XCTAssertLessThan(abs(description.frame.midY - amount.frame.midY), 24)
        XCTAssertFalse(app.buttons["Detalii"].exists)
        XCTAssertFalse(app.textFields["entry.note"].exists)
        XCTAssertTrue(app.buttons["entry.date"].label.contains("Azi"))
        XCTAssertLessThan(app.buttons["entry.close"].frame.midX, app.frame.midX)
        amount.typeText("25")
        XCTAssertFalse(app.buttons["entry.save"].isEnabled)
        description.tap(); description.typeText("   ")
        XCTAssertFalse(app.buttons["entry.save"].isEnabled)
        replace(description, with: "Cafea")
        XCTAssertTrue(app.buttons["entry.save"].isEnabled)
        attach("30-compact-entry-keyboard", app)
        let save = app.buttons["entry.save"]
        let close = app.buttons["entry.close"]
        XCTAssertGreaterThan(save.frame.midX, app.frame.midX)
        XCTAssertLessThan(abs(save.frame.midY - close.frame.midY), 12)
        XCTAssertLessThan(save.frame.maxY, 150)
        XCTAssertEqual(app.buttons.matching(identifier: "entry.save").count, 1)
        XCTAssertFalse(app.buttons["entry.keyboardDone"].exists)
        XCTAssertFalse(app.buttons["entry.pickerDone"].exists)
        app.buttons["entry.date"].tap()
        let date = app.datePickers["entry.datePicker"]
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        XCTAssertEqual(date.pickerWheels.count, 3)
        XCTAssertFalse(app.popovers.firstMatch.exists)
        date.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "1")
        XCTAssertTrue(app.buttons["entry.date"].label.contains(Calendar.current.component(.day, from: .now) == 1 ? "Azi" : "1 "))
        attach("60-native-date-and-top-save", app)
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("25"))
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("0,00"))
    }

    @MainActor func testNativeInputPickersKeepDraftAndKeyboardFlow() throws {
        let app = launch("-budget-notes-tests")
        app.buttons["ledger.add"].tap()
        let amount = app.textFields["entry.amount"]
        let description = app.textFields["entry.merchant"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        amount.tap(); amount.typeText("42")
        description.tap(); description.typeText("Prânz")
        app.buttons["entry.category"].tap()
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(wheel.frame.minY, app.frame.midY)
        XCTAssertTrue(app.buttons["entry.save"].isHittable)
        XCTAssertFalse(app.popovers.firstMatch.exists)
        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertFalse(app.buttons["entry.pickerDone"].exists)
        XCTAssertFalse(app.buttons["entry.keyboardDone"].exists)
        XCTAssertLessThan(app.buttons["entry.save"].frame.maxY, 150)
        attach("50-native-category-input", app)
        wheel.adjust(toPickerWheelValue: "Transport")
        XCTAssertTrue(app.buttons["entry.category"].label.contains("Transport"))
        XCTAssertEqual(amount.value as? String, "42")
        XCTAssertEqual(description.value as? String, "Prânz")
        app.buttons["entry.account"].tap()
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        wheel.adjust(toPickerWheelValue: "Numerar")
        XCTAssertTrue(app.buttons["entry.account"].label.contains("Numerar"))
        attach("51-native-account-input", app)
        XCTAssertEqual(description.value as? String, "Prânz")
        description.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertTrue(wheel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(description.value as? String, "Prânz")
        replace(description, with: "Prânz afară\n")
        XCTAssertEqual(description.value as? String, "Prânz afară")
        app.buttons["entry.category"].tap()
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        XCTAssertTrue((wheel.value as? String ?? "").contains("Transport"))
        wheel.adjust(toPickerWheelValue: "Restaurante și cafenele")
        XCTAssertTrue(app.buttons["entry.category"].label.contains("Restaurante și cafenele"))
        attach("52-native-input-long-category", app)
        app.buttons["entry.account"].tap()
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        XCTAssertTrue((wheel.value as? String ?? "").contains("Numerar"))
        XCTAssertEqual(amount.value as? String, "42")
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("1.842"))
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("1.800"))
    }

    @MainActor func testTransferWithOneAccountShowsEmptyInput() throws {
        let app = launch()
        app.buttons["ledger.add"].tap()
        XCTAssertTrue(app.buttons["entry.kind.transfer"].waitForExistence(timeout: 5))
        app.buttons["entry.kind.transfer"].tap()
        app.buttons["entry.destination"].tap()
        let message = app.staticTexts["entry.accounts.empty"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.isHittable)
        XCTAssertGreaterThan(message.frame.minY, app.frame.midY)
        XCTAssertFalse(app.pickerWheels.firstMatch.exists)
        XCTAssertFalse(app.buttons["entry.save"].isEnabled)
        attach("53-native-empty-destination", app)
        app.textFields["entry.amount"].tap()
        XCTAssertTrue(message.waitForNonExistence(timeout: 5))
    }

    @MainActor func testManualRecurringToggleCreatesSchedule() throws {
        let app = launch()
        app.buttons["ledger.add"].tap()
        XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 5))
        app.textFields["entry.amount"].typeText("49")
        app.textFields["entry.merchant"].tap(); app.textFields["entry.merchant"].typeText("Abonament")
        let recurring = app.switches["entry.recurring"]
        XCTAssertTrue(recurring.exists)
        XCTAssertEqual(recurring.value as? String, "0")
        XCTAssertFalse(app.buttons["entry.frequency"].exists)
        recurring.tap()
        XCTAssertTrue(app.buttons["entry.frequency"].label.contains("Lunar"))
        app.buttons["entry.frequency"].tap()
        pickInput("Anual", app)
        XCTAssertTrue(app.buttons["entry.frequency"].label.contains("Anual"))
        recurring.tap()
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["entry.frequency"].exists)
        recurring.tap()
        XCTAssertTrue(app.buttons["entry.frequency"].label.contains("Lunar"))
        app.buttons["entry.frequency"].tap()
        pickInput("Săptămânal", app)
        attach("61-recurring-toggle-and-frequency", app)
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("49"))
        menu("Setări", app); app.buttons["settings.recurring"].tap()
        XCTAssertTrue(app.buttons["rule.menu.Abonament"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Săptămânal")).firstMatch.exists)
        attach("62-manually-created-schedule", app)
    }

    @MainActor func testMonthlyIncomeAcrossAccountsAndCurrencies() throws {
        let app = launch("-budget-notes-tests")
        XCTAssertTrue(app.buttons["home.income"].label.contains("6.000"))
        openHome("home.income", app)
        XCTAssertTrue(app.staticTexts["home.focus.total"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.focus.total"].label.contains("6.000"))
        XCTAssertTrue(row("Salariu", app).exists)
        XCTAssertFalse(row("Chirie", app).exists)
        XCTAssertFalse(row("Transport de verificat", app).exists)
        home(app)
        app.buttons["ledger.add"].tap()
        XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 5))
        attach("20-minimal-entry-expense", app)
        app.buttons["entry.kind.income"].tap()
        XCTAssertTrue(app.buttons["entry.kind.income"].isSelected)
        app.buttons["entry.account"].tap()
        pickInput("Numerar", app)
        app.buttons["entry.category"].tap()
        pickInput("Salariu", app)
        app.buttons["entry.kind.income"].tap()
        XCTAssertTrue(app.buttons["entry.category"].label.contains("Salariu"))
        app.textFields["entry.amount"].tap(); app.textFields["entry.amount"].typeText("200")
        app.textFields["entry.merchant"].tap(); app.textFields["entry.merchant"].typeText("Bonus\n")
        attach("21-minimal-entry-income", app)
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.income"].label.contains("6.200"))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("1.800"))
        XCTAssertTrue(app.staticTexts["home.remaining"].label.contains("2.200"))
        attach("22-home-with-income", app)
        openHome("home.income", app)
        XCTAssertTrue(row("Bonus", app).waitForExistence(timeout: 5))
        XCTAssertTrue(row("Salariu", app).exists)
        XCTAssertTrue(app.staticTexts["home.focus.total"].label.contains("6.200"))
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(row("Bonus", app).waitForNonExistence(timeout: 5))
        home(app)
        XCTAssertTrue(app.buttons["home.income"].label.contains("6.000"))
        app.buttons["ledger.add"].tap()
        XCTAssertTrue(app.buttons["entry.kind.income"].waitForExistence(timeout: 5))
        app.buttons["entry.kind.income"].tap()
        app.buttons["entry.account"].tap()
        pickInput("Euro", app)
        app.textFields["entry.amount"].tap(); app.textFields["entry.amount"].typeText("20")
        app.textFields["entry.merchant"].tap(); app.textFields["entry.merchant"].typeText("Venit EUR\n")
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.income"].label.contains("6.000"))
        app.buttons["home.menu"].tap()
        if !app.buttons["EUR"].firstMatch.exists { app.buttons["Moneda"].tap() }
        app.buttons["EUR"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["home.received"].label.contains("20,00"))
        XCTAssertTrue(app.staticTexts["home.received"].label.contains("EUR"))
        openHome("home.income", app)
        XCTAssertTrue(row("Venit EUR", app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("Salariu", app).exists)
        let previous = Calendar.current.date(byAdding: .month, value: -1, to: .now)!
        chooseMonth(previous, app)
        XCTAssertTrue(app.staticTexts["home.focus.total"].label.contains("0 EUR"))
        XCTAssertFalse(row("Venit EUR", app).exists)
        home(app)
        XCTAssertTrue(app.staticTexts["home.received"].label.contains("0,00"))
        XCTAssertTrue(app.staticTexts["home.received"].label.contains("EUR"))
    }

    @MainActor func testCrossCurrencyTransferRequiresReceivedAmount() throws {
        let app = launch("-budget-notes-tests")
        app.buttons["ledger.add"].tap()
        XCTAssertTrue(app.buttons["entry.kind.transfer"].waitForExistence(timeout: 5))
        app.buttons["entry.kind.transfer"].tap()
        app.buttons["entry.destination"].tap()
        pickInput("Euro", app)
        XCTAssertTrue(app.textFields["entry.received"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["entry.destination"].label.contains("Euro"))
        app.textFields["entry.amount"].tap(); app.textFields["entry.amount"].typeText("100")
        XCTAssertTrue(app.textFields["entry.received"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["entry.save"].isEnabled)
        app.textFields["entry.received"].tap(); app.textFields["entry.received"].typeText("20")
        app.textFields["entry.merchant"].tap(); app.textFields["entry.merchant"].typeText("Schimb valutar\n")
        attach("23-minimal-transfer", app)
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("1.800"))
        XCTAssertTrue(app.buttons["home.income"].label.contains("6.000"))
        openHome("home.transactions", app)
        XCTAssertTrue(row("Schimb valutar", app).waitForExistence(timeout: 5))
        XCTAssertTrue(row("Schimb valutar", app).label.contains("20 EUR"))
        app.buttons["ledger.undo"].tap()
        XCTAssertTrue(row("Schimb valutar", app).waitForNonExistence(timeout: 5))
    }

    @MainActor func testIncomeTransferAccounts() throws {
        let app = launch()
        menu("Conturi", app)
        app.buttons["accounts.add"].tap()
        let name = app.textFields["account.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Numerar")
        let balance = app.textFields["account.opening"]; balance.tap(); balance.typeText("100")
        app.buttons["account.save"].tap()
        XCTAssertTrue(app.buttons["account.row.Numerar"].waitForExistence(timeout: 5))
        app.buttons["accounts.close"].tap()
        add(app, kind: "Venit", amount: "7000", name: "Salariu primit")
        app.buttons["ledger.add"].tap()
        XCTAssertTrue(app.buttons["entry.kind.transfer"].waitForExistence(timeout: 5))
        app.buttons["entry.kind.transfer"].tap()
        let amount = app.textFields["entry.amount"]; amount.tap(); amount.typeText("300")
        app.buttons["entry.destination"].tap()
        pickInput("Numerar", app)
        let merchant = app.textFields["entry.merchant"]; merchant.tap(); merchant.typeText("Retragere\n")
        app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("0,00"))
        menu("Conturi", app)
        XCTAssertTrue(app.buttons["account.row.Numerar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["account.row.Numerar"].label.contains("400"))
    }

    @MainActor func testRecurringConfirmationAndUndo() throws {
        let app = launch()
        menu("Setări", app); app.buttons["settings.recurring"].tap(); app.buttons["rules.add"].tap()
        XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 5))
        app.textFields["entry.amount"].tap(); app.textFields["entry.amount"].typeText("49")
        app.textFields["entry.merchant"].tap(); app.textFields["entry.merchant"].typeText("Netflix\n")
        app.buttons["rule.save"].tap()
        XCTAssertTrue(app.buttons["rule.confirm.Netflix"].waitForExistence(timeout: 5))
        home(app); XCTAssertTrue(app.staticTexts["home.spent"].label.contains("0,00"))
        menu("Setări", app); app.buttons["settings.recurring"].tap(); app.buttons["rule.confirm.Netflix"].tap()
        XCTAssertTrue(app.buttons["entry.save"].waitForExistence(timeout: 5)); app.buttons["entry.save"].tap()
        XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5)); app.buttons["ledger.undo"].tap()
        home(app); XCTAssertTrue(app.staticTexts["home.spent"].label.contains("0,00"))
        menu("Setări", app); app.buttons["settings.recurring"].tap()
        app.buttons["rule.menu.Netflix"].tap(); app.buttons["Pauză"].tap()
        XCTAssertFalse(app.buttons["rule.confirm.Netflix"].exists)
    }

    @MainActor func testCategoriesAndEnglishPreferences() throws {
        let app = launch()
        menu("Setări", app); app.buttons["settings.categories"].tap(); app.buttons["categories.add"].tap()
        let name = app.textFields["category.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Caine\n")
        app.buttons["category.save"].tap()
        for _ in 0..<4 { if app.buttons["category.edit.Caine"].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.buttons["category.edit.Caine"].exists)
        app.buttons["category.delete.Caine"].tap(); app.buttons["Șterge categoria"].tap()
        XCTAssertTrue(app.buttons["category.edit.Caine"].waitForNonExistence(timeout: 5))
        app.buttons["categories.close"].tap(); app.buttons["settings.preferences"].tap()
        app.buttons["onboarding.languageDropdown"].tap(); app.buttons["onboarding.language.en"].tap()
        app.buttons["preferences.save"].tap()
        home(app)
        XCTAssertTrue(app.staticTexts["Expenses"].waitForExistence(timeout: 5))
        attach("04-notes-english-home", app)
        app.buttons["home.menu"].tap()
        XCTAssertEqual(app.buttons["home.menu.transactions"].label, "Transactions")
        XCTAssertEqual(app.buttons["home.menu.categories"].label, "Categories")
    }

    @MainActor func testOnboardingCurrency() throws {
        let app = XCUIApplication(); app.launchArguments = ["-budget-onboarding-tests"]; app.launch()
        XCTAssertTrue(app.buttons["onboarding.languageDropdown"].waitForExistence(timeout: 8))
        app.buttons["onboarding.languageDropdown"].tap(); app.buttons["onboarding.language.ro"].tap()
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.buttons["onboarding.currencyDropdown"].waitForExistence(timeout: 5))
        app.buttons["onboarding.currencyDropdown"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "EUR")).firstMatch.tap()
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.buttons["ledger.add"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["home.spent"].label.contains("EUR"))
        app.buttons["ledger.add"].tap()
        XCTAssertTrue(app.buttons["entry.account"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["entry.account"].label.contains("EUR"))
    }

    @MainActor func testWidgetRoutesRemainManual() throws {
        let app = launch()
        app.open(URL(string: "personalbudget://add/income")!)
        XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["entry.kind.income"].isSelected)
        app.buttons["entry.close"].tap()
        app.open(URL(string: "personalbudget://add/manual")!)
        XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["dictation.cancel"].exists)
    }

    @MainActor private func pickInput(_ value: String, _ app: XCUIApplication) {
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        wheel.adjust(toPickerWheelValue: value)
    }

    @MainActor private func launch(_ argument: String = "-budget-ui-tests") -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = [argument]; app.launch()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 8)); return app
    }
    @MainActor private func back(_ app: XCUIApplication) {
        let button = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(button.waitForExistence(timeout: 4)); button.tap()
    }
    @MainActor private func revealCategoryChart(_ app: XCUIApplication) {
        let chart = app.scrollViews["home.categoryChart"]
        for _ in 0..<6 {
            if chart.isHittable && chart.frame.maxY < app.buttons["ledger.voice"].frame.minY - 8 { break }
            app.swipeUp()
        }
        XCTAssertTrue(chart.isHittable)
    }
    @MainActor private func home(_ app: XCUIApplication) {
        for _ in 0..<6 {
            if app.buttons["home.focus.close"].isHittable { app.buttons["home.focus.close"].tap(); continue }
            if app.buttons["home.settings"].isHittable { return }
            if app.buttons["home.settings"].exists && !app.navigationBars.buttons.firstMatch.exists { app.swipeDown() }
            else { back(app) }
        }
        XCTAssertTrue(app.buttons["home.settings"].isHittable)
    }
    @MainActor private func openHome(_ identifier: String, _ app: XCUIApplication) {
        home(app)
        if identifier == "home.transactions" || identifier == "home.categories" {
            app.buttons["home.menu"].tap()
            let menuID = identifier == "home.transactions" ? "home.menu.transactions" : "home.menu.categories"
            let target = app.buttons[menuID]
            XCTAssertTrue(target.waitForExistence(timeout: 4)); target.tap(); return
        }
        let target = app.buttons[identifier]
        for _ in 0..<6 {
            if target.isHittable { break }
            if target.exists && target.frame.minY < app.buttons["period.month"].frame.maxY { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(target.isHittable); target.tap()
    }
    @MainActor private func menu(_ title: String, _ app: XCUIApplication) {
        home(app)
        if title == "Setări" { app.buttons["home.settings"].tap(); return }
        app.buttons["home.menu"].tap(); let button = app.buttons[title].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 4)); button.tap()
    }
    @MainActor private func chooseMonth(_ date: Date, _ app: XCUIApplication) {
        for _ in 0..<5 { if app.buttons["period.month"].isHittable { break }; app.swipeDown() }
        app.buttons["period.month"].tap()
        let year = Calendar.current.component(.year, from: date)
        let shown = Int(app.staticTexts["period.year"].label) ?? year
        for _ in 0..<abs(shown - year) { app.buttons[year < shown ? "period.previousYear" : "period.nextYear"].tap() }
        app.buttons["period.pick.\(Calendar.current.component(.month, from: date))"].tap()
    }
    @MainActor private func add(_ app: XCUIApplication, kind: String, amount: String, name: String) {
        app.buttons["ledger.add"].tap()
        XCTAssertTrue(app.textFields["entry.amount"].waitForExistence(timeout: 5))
        if kind != "Cheltuială" { app.buttons[kind == "Venit" ? "entry.kind.income" : "entry.kind.transfer"].tap() }
        app.textFields["entry.amount"].tap(); app.textFields["entry.amount"].typeText(amount)
        app.textFields["entry.merchant"].tap(); app.textFields["entry.merchant"].typeText(name + "\n")
        app.buttons["entry.save"].tap(); XCTAssertTrue(app.buttons["ledger.undo"].waitForExistence(timeout: 5))
    }
    @MainActor private func row(_ name: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "ledger.row.\(name)").firstMatch
    }
    @MainActor private func replace(_ field: XCUIElement, with text: String) {
        field.tap(); let value = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count + 2) + text)
    }
    @MainActor private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
