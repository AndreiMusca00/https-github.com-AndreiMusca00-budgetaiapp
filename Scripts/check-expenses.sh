#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d /private/tmp/personal-budget-expense-checks.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
cd "$project_dir"
xcrun swiftc -parse-as-library -module-cache-path "$check_dir/module-cache" \
  'Personal Budget App/Core/Currency/CurrencyOption.swift' \
  'Personal Budget App/Core/Preferences/UserPreferences.swift' \
  'Personal Budget App/Core/Speech/BudgetLanguage.swift' \
  'Personal Budget App/Core/Ledger/'*.swift \
  'Personal Budget App/Core/Expenses/MoneyAmount.swift' \
  'Personal Budget App/Core/Expenses/Expense.swift' \
  'Personal Budget App/Core/Expenses/ExpenseRepository.swift' \
  'Personal Budget App/Core/Categories/ExpenseCategory.swift' \
  'Personal Budget App/Core/Persistence/BudgetDatabase.swift' \
  'Personal Budget App/Core/Navigation/ExpenseRouter.swift' \
  'Personal Budget App/Core/Speech/DictationTranscript.swift' \
  Tests/ExpenseChecks.swift -o "$check_dir/expense-checks"
"$check_dir/expense-checks"
