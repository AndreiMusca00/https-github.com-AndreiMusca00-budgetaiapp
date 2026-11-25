#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
check_dir=$(mktemp -d /private/tmp/personal-budget-checks.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
cd "$project_dir"
xcrun swiftc -parse-as-library -module-cache-path "$check_dir/module-cache" \
  'Personal Budget App/Core/Currency/CurrencyOption.swift' \
  'Personal Budget App/Core/Speech/SpeechLanguage.swift' \
  'Personal Budget App/Core/Speech/BudgetLanguage.swift' \
  'Personal Budget App/Core/Speech/DictationTranscript.swift' \
  'Personal Budget App/Core/Speech/VoiceLevel.swift' \
  'Personal Budget App/Features/Onboarding/OnboardingFlow.swift' \
  'Personal Budget App/Core/Preferences/UserPreferences.swift' \
  'Personal Budget App/Core/Preferences/PreferencesStore.swift' \
  'Personal Budget App/Core/Drafts/TransactionDraftStore.swift' \
  Tests/PreferencesChecks.swift -o "$check_dir/preferences-checks"
"$check_dir/preferences-checks"
