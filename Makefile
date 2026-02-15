.PHONY: test analyze lint-functions check-functions ci

## Flutter
test:
	flutter test

analyze:
	flutter analyze

## Supabase Edge Functions (Deno)
lint-functions:
	cd supabase && deno lint functions/

check-functions:
	cd supabase && deno check \
		functions/parse-novel-url/index.ts \
		functions/register-bookmark/index.ts \
		functions/crawl-updates/index.ts \
		functions/check-new-novels/index.ts \
		functions/check-legal-updates/index.ts \
		functions/record-consent/index.ts

## All checks
ci: analyze test lint-functions check-functions
	@echo "All checks passed!"
