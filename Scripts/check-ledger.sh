#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d /private/tmp/budget-ledger-checks.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
cd "$project_dir"
xcrun swiftc -parse-as-library -module-cache-path "$check_dir/cache" \
  Tests/LegacySchema.swift -o "$check_dir/legacy"
"$check_dir/legacy" "$check_dir/legacy.store"
# Preserve the previous seven-model store, including a real overall budget without categoryID.
python3 - "$check_dir/PreviousLedgerModels.swift" <<'PY'
from pathlib import Path
import sys
source = Path('Personal Budget App/Core/Ledger/LedgerModels.swift').read_text()
start = source.index('@Model\nfinal class MonthlyBudget')
end = source.index('struct EntryInput', start)
Path(sys.argv[1]).write_text(source[:start] + source[end:])
PY
xcrun swiftc -parse-as-library -module-cache-path "$check_dir/cache" \
  'Personal Budget App/Core/Currency/CurrencyOption.swift' \
  'Personal Budget App/Core/Preferences/UserPreferences.swift' \
  'Personal Budget App/Core/Speech/BudgetLanguage.swift' \
  'Personal Budget App/Core/Expenses/MoneyAmount.swift' \
  'Personal Budget App/Core/Expenses/Expense.swift' \
  'Personal Budget App/Core/Categories/ExpenseCategory.swift' \
  'Personal Budget App/Core/Ledger/RecurrenceRule.swift' \
  "$check_dir/PreviousLedgerModels.swift" Tests/PreviousBudgetSchema.swift -o "$check_dir/previous"
"$check_dir/previous" "$check_dir/previous.store"
xcrun swiftc -parse-as-library -module-cache-path "$check_dir/cache" \
  'Personal Budget App/Core/Currency/CurrencyOption.swift' \
  'Personal Budget App/Core/Preferences/UserPreferences.swift' \
  'Personal Budget App/Core/Speech/BudgetLanguage.swift' \
  'Personal Budget App/Core/Expenses/MoneyAmount.swift' \
  'Personal Budget App/Core/Expenses/Expense.swift' \
  'Personal Budget App/Core/Expenses/ExpenseRepository.swift' \
  'Personal Budget App/Core/Categories/ExpenseCategory.swift' \
  'Personal Budget App/Core/Persistence/BudgetDatabase.swift' \
  'Personal Budget App/Core/Ledger/'*.swift \
  Tests/LedgerChecks.swift -o "$check_dir/ledger"
"$check_dir/ledger" "$check_dir/legacy.store" "$check_dir/previous.store"
