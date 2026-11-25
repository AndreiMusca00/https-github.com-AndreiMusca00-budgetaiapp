import SwiftUI

struct OnboardingCurrencyStep: View {
    let language: BudgetLanguage
    @Binding var currencyCode: String?
    @State private var showsPicker = false

    private var copy: OnboardingCopy { OnboardingCopy(language: language) }
    private var currencyName: String {
        guard let currencyCode else { return copy.chooseCurrency }
        return Locale(identifier: language.rawValue).localizedString(forCurrencyCode: currencyCode) ?? currencyCode
    }

    var body: some View {
        Button { showsPicker = true } label: {
            HStack(spacing: 16) {
                Text(currencyCode ?? "—")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(BudgetStyle.accent)
                    .frame(minWidth: 52, minHeight: 48)
                    .background(BudgetStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                Text(currencyName).font(.body.weight(.semibold)).foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(.primary.opacity(0.04), in: Circle())
            }
            .padding(18).frame(minHeight: 84)
            .background(BudgetStyle.card, in: RoundedRectangle(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.primary.opacity(0.06), lineWidth: 1) }
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.currencyDropdown")
        .sheet(isPresented: $showsPicker) {
            PreferencePicker(
                title: copy.chooseCurrency,
                options: CurrencyOption.all.map {
                    PreferenceOption(id: $0.id,
                        title: Locale(identifier: language.rawValue).localizedString(forCurrencyCode: $0.id) ?? $0.id,
                        subtitle: $0.id)
                },
                selectedID: $currencyCode,
                searchPrompt: copy.search,
                closeTitle: copy.close
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}
