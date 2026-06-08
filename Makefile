.PHONY: test analyze lint-functions check-functions ci \
        run-dev run-prod \
        build-ios-dev build-ios-prod \
        build-android-dev build-android-prod \
        migrate-dev migrate-prod \
        deploy-functions-dev deploy-functions-prod \
        link-dev link-prod

DEV_REF  = oszscaegphdrdlypofqi
PROD_REF = zrxsapgvlflxitddeqcn

# ────────────────────────────────────────
## Flutter
# ────────────────────────────────────────
test:
	flutter test

analyze:
	flutter analyze

run-dev:
	flutter run --dart-define=FLAVOR=development

run-prod:
	flutter run --dart-define=FLAVOR=production

build-ios-dev:
	flutter build ipa --dart-define=FLAVOR=development

build-ios-prod:
	flutter build ipa --dart-define=FLAVOR=production

build-android-dev:
	flutter build appbundle --dart-define=FLAVOR=development

build-android-prod:
	flutter build appbundle --dart-define=FLAVOR=production

# ────────────────────────────────────────
## Supabase – project linking
# ────────────────────────────────────────
link-dev:
	supabase link --project-ref $(DEV_REF)

link-prod:
	supabase link --project-ref $(PROD_REF)

# ────────────────────────────────────────
## Supabase – DB migrations
# ────────────────────────────────────────
migrate-dev: link-dev
	supabase db push

migrate-prod: link-prod
	supabase db push

# ────────────────────────────────────────
## Supabase – Edge Functions
# ────────────────────────────────────────
deploy-functions-dev:
	supabase functions deploy --project-ref $(DEV_REF)

deploy-functions-prod:
	supabase functions deploy --project-ref $(PROD_REF)

# ────────────────────────────────────────
## Supabase Edge Functions (Deno)
# ────────────────────────────────────────
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

# ────────────────────────────────────────
## All checks
# ────────────────────────────────────────
ci: analyze test lint-functions check-functions
	@echo "All checks passed!"
