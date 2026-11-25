import SwiftUI
import Observation

enum LedgerSheet: Identifiable {
    case create(EntryKind), edit(UUID), occurrence(UUID, Date)
    case accounts, recurrences, budget(Date, String), categoryBudget(Date, String, UUID), budgets(Date, String), drafts, preferences
    var presentsFullScreen: Bool {
        switch self {
        case .create, .edit, .occurrence: true
        default: false
        }
    }
    var id: String {
        switch self {
        case .create(let kind): "new-\(kind.rawValue)"
        case .edit(let id): "edit-\(id)"
        case .occurrence(let id, let date): "due-\(id)-\(date.timeIntervalSince1970)"
        case .accounts: "accounts"
        case .recurrences: "recurrences"
        case .budget(let date, let currency): "budget-\(LedgerMath.monthKey(date))-\(currency)"
        case .categoryBudget(let date, let currency, let id): "budget-\(LedgerMath.monthKey(date))-\(currency)-\(id)"
        case .budgets(let date, let currency): "budgets-\(LedgerMath.monthKey(date))-\(currency)"
        case .drafts: "drafts"
        case .preferences: "preferences"
        }
    }
}

@MainActor
@Observable
final class LedgerSession {
    var sheet: LedgerSheet?
    var showsDictation = false
    var month = Date.now
    var currency: String?
    var toast: LedgerChange?
    private var toastID = UUID()
    @ObservationIgnored private var expiry: Task<Void, Never>?

    func show(_ change: LedgerChange) {
        expiry?.cancel()
        toast = change
        let id = UUID()
        toastID = id
        expiry = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            guard let self, self.toastID == id else { return }
            self.toast = nil
        }
    }
    func undo() {
        guard let action = toast?.undo else { return }
        do {
            try action()
            expiry?.cancel()
            toast = nil
        } catch {
            expiry?.cancel()
            toast = LedgerChange(message: "Nu am putut anula modificarea.", undo: action)
        }
    }
}

struct LedgerToast: View {
    @Environment(LedgerSession.self) private var session
    var body: some View {
        if let toast = session.toast {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(BudgetStyle.accent)
                Text(tr(toast.message)).font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if toast.undo != nil {
                    Button(tr("Anulează")) { session.undo() }
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("ledger.undo")
                }
            }
            .padding(16).background {
                Color.clear.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("ledger.toast")
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
