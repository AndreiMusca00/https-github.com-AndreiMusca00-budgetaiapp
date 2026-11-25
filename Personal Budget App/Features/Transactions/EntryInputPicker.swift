import SwiftUI
import UIKit

struct EntryInputOption: Equatable {
    let id: String?
    let title: String
    let emoji: String
    var detail: String?

    var displayTitle: String {
        (emoji.isEmpty ? title : emoji + " " + title) + (detail.map { " · " + $0 } ?? "")
    }
}

struct EntryInputSelection {
    let id: String
    let title: String
    var options: [EntryInputOption] = []
    var selectedID: String? = nil
    var emptyMessage = ""
    var date: Date? = nil
    var maximumDate: Date? = nil
    var localeIdentifier = Locale.current.identifier
}

/// Owns a native inputView so selection uses the keyboard area and its system transitions.
struct EntryInputPicker: UIViewRepresentable {
    let selection: EntryInputSelection?
    let onSelect: (String?) -> Void
    let onDateChange: (Date) -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextField {
        let responder = UITextField(frame: .zero)
        responder.borderStyle = .none
        responder.tintColor = .clear
        responder.isAccessibilityElement = false
        responder.inputAssistantItem.leadingBarButtonGroups = []
        responder.inputAssistantItem.trailingBarButtonGroups = []
        responder.delegate = context.coordinator
        responder.inputView = context.coordinator.input
        context.coordinator.responder = responder
        return responder
    }

    func updateUIView(_ view: UITextField, context: Context) {
        context.coordinator.update(selection, onSelect: onSelect, onDateChange: onDateChange, onDismiss: onDismiss)
    }

    static func dismantleUIView(_ view: UITextField, coordinator: Coordinator) {
        coordinator.selection = nil
        coordinator.onDismiss = nil
        view.resignFirstResponder()
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewAccessibilityDelegate, UITextFieldDelegate {
        let input = EntryWheelInputView()
        weak var responder: UITextField?
        var selection: EntryInputSelection?
        var onDismiss: (() -> Void)?
        private var onSelect: ((String?) -> Void)?
        private var onDateChange: ((Date) -> Void)?

        override init() {
            super.init()
            input.picker.dataSource = self
            input.picker.delegate = self
            input.picker.accessibilityIdentifier = "entry.inputPicker"
            input.datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        }

        func update(_ next: EntryInputSelection?, onSelect: @escaping (String?) -> Void, onDateChange: @escaping (Date) -> Void, onDismiss: @escaping () -> Void) {
            let previous = selection
            selection = next
            self.onSelect = onSelect
            self.onDateChange = onDateChange
            self.onDismiss = onDismiss
            guard let next else {
                if responder?.isFirstResponder == true { responder?.resignFirstResponder() }
                return
            }
            let isDate = next.date != nil
            input.datePicker.isHidden = !isDate
            input.empty.text = next.emptyMessage
            input.empty.isHidden = isDate || !next.options.isEmpty
            input.picker.isHidden = isDate || next.options.isEmpty
            if let date = next.date {
                if input.datePicker.locale?.identifier != next.localeIdentifier {
                    input.datePicker.locale = Locale(identifier: next.localeIdentifier)
                }
                input.datePicker.maximumDate = next.maximumDate
                if abs(input.datePicker.date.timeIntervalSince(date)) > 0.5 {
                    input.datePicker.setDate(date, animated: false)
                }
            } else {
                if previous?.options != next.options { input.picker.reloadAllComponents() }
                let row = next.options.firstIndex { $0.id == next.selectedID } ?? 0
                if !next.options.isEmpty && input.picker.selectedRow(inComponent: 0) != row {
                    input.picker.selectRow(row, inComponent: 0, animated: false)
                }
            }
            if previous?.id != next.id {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.selection?.id == next.id,
                          let responder = self.responder, responder.window != nil else { return }
                    if !responder.isFirstResponder { responder.becomeFirstResponder() }
                }
            }
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            selection?.options.count ?? 0
        }
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat { 48 }
        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            option(at: row)?.title
        }
        func pickerView(_ pickerView: UIPickerView, accessibilityLabelForComponent component: Int) -> String? {
            selection?.title
        }
        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = (view as? UILabel) ?? UILabel()
            label.text = option(at: row)?.displayTitle
            label.accessibilityLabel = option(at: row)?.title
            label.font = UIFont.systemFont(ofSize: 18, weight: .medium).rounded()
            label.textColor = .label
            label.textAlignment = .center
            label.numberOfLines = 2
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.8
            return label
        }
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            if let option = option(at: row) { onSelect?(option.id) }
        }
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool { false }
        func textFieldDidEndEditing(_ textField: UITextField) {
            guard let endedID = selection?.id else { return }
            commitSelection()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.selection?.id == endedID else { return }
                self.onDismiss?()
            }
        }
        @objc private func dateChanged() { onDateChange?(input.datePicker.date) }
        private func commitSelection() {
            if selection?.date != nil { onDateChange?(input.datePicker.date) }
            else if let option = option(at: input.picker.selectedRow(inComponent: 0)) { onSelect?(option.id) }
        }
        private func option(at index: Int) -> EntryInputOption? {
            guard let options = selection?.options, options.indices.contains(index) else { return nil }
            return options[index]
        }
    }
}

final class EntryWheelInputView: UIInputView {
    let picker = UIPickerView()
    let datePicker = UIDatePicker()
    let empty = UILabel()

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 216), inputViewStyle: .keyboard)
        allowsSelfSizing = true
        picker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.tintColor = UIColor(BudgetStyle.accent)
        datePicker.accessibilityIdentifier = "entry.datePicker"
        datePicker.isHidden = true
        empty.translatesAutoresizingMaskIntoConstraints = false
        empty.textAlignment = .center
        empty.numberOfLines = 2
        empty.font = UIFont.systemFont(ofSize: 15, weight: .medium).rounded()
        empty.textColor = .secondaryLabel
        empty.accessibilityIdentifier = "entry.accounts.empty"
        addSubview(picker)
        addSubview(datePicker)
        addSubview(empty)
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            picker.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            picker.topAnchor.constraint(equalTo: topAnchor),
            picker.bottomAnchor.constraint(equalTo: bottomAnchor),
            datePicker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            datePicker.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            datePicker.topAnchor.constraint(equalTo: topAnchor),
            datePicker.bottomAnchor.constraint(equalTo: bottomAnchor),
            empty.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            empty.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            empty.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 216) }
}

private extension UIFont {
    func rounded() -> UIFont {
        fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: pointSize) } ?? self
    }
}
