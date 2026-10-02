# Appartements ERP — Flutter/Appwrite base project + Auth feature (5.1)

Clean Architecture (Data / Domain / Presentation-controllers-only), BLoC,
Appwrite backend. See the root of the custom instructions for the general
rules this project follows; this README covers only what's specific to
what was generated.

## What's included

- **`core/`** — app-wide, reusable building blocks: `BaseException` /
  `Failure`, `FutureEither<T>`, `UseCase<Type, Params>` / `NoParams`, the
  single app-wide `GetIt` service locator (`initServiceLocator()`),
  `EnvConfig` (flavor-aware env loading), and Appwrite schema constants.
- **`features/auth/`** — full Data + Domain, controller-only Presentation
  for cahier des charges §5.1 (Authentification & profils), plus the
  parts of §5.7 (Gestion des gestionnaires) that are identity/account
  concerns rather than location-assignment concerns.
- **`features/company/`** — intentionally minimal. Only `Company` entity +
  `getCompanyById`, because Auth's registration flow needs a Company
  document to attach a new Admin to. Full CRUD/activation is §5.2 and
  should extend this feature, not duplicate it.
- **`functions/`** — **exactly one Appwrite Function, ever: `api`**
  (Python, `functions/api/src/main.py`). This is a project-wide policy,
  not an Auth-specific one: every feature this project ever adds routes
  its privileged server-side operations through this SAME function,
  selected by a `resource` field in the request body
  (`auth.create-gestionnaire-account` today; a future feature adds e.g.
  `company.create-company` to the same file, never a second function
  directory). Started as six separate functions, consolidated into one to
  fit an Appwrite plan's function-count limit — see the module docstring
  at the top of `main.py` for the exact extension convention, and "Why
  Cloud Functions" below for why so much of Auth needs one at all.
- **`appwrite_setup.md`** — CLI commands for database/collections/
  attributes/indexes/permissions/functions.

## Why Cloud Functions for so much of Auth?

`role` and `companyId` are the two fields multi-tenancy and RBAC hinge on.
If the client could write them directly, any authenticated (or even
anonymous, for sign-up) request could self-assign `role: "admin"` or
attach itself to another company. So:

- The `user_profiles` (and `companies`) collections have **no client-side
  create permission at all** — only a Cloud Function's Server-SDK API key
  can create documents in them.
- Tenant isolation for *reads* is enforced with **one Appwrite Team per
  company** (`team_id == company_id`); `user_profiles` documents get
  `read(team:<companyId>)` permission at creation time, so Appwrite's own
  permission engine — not just function-side checks — keeps one
  company's Admin from ever listing another company's Gestionnaires.
- Login/OTP by **phone number** needed a way to resolve an identifier to
  an account without exposing the whole `user_profiles` collection to
  public/cross-tenant reads (which would leak PII by phone-number
  probing) — hence the small `auth.resolve-login-identifier` resource
  (part of the project's one shared `api` function) that returns only
  `{userId, email}`.
- Password reset is **OTP-based, no MFA**, and to avoid depending on
  Appwrite's `updatePassword(oldPassword)` semantics (ambiguous once a
  session was opened via an OTP token rather than a password), the new
  password is force-set server-side via the Users API once the
  OTP-derived session has already proven identity.

## Known assumptions / things to verify before shipping

These are flagged inline in code comments too:

1. **Appwrite Account API method names** for email/phone OTP tokens
   (`createEmailToken` / `createPhoneToken` / `createSession`) and the
   Execution model's `responseBody` / `responseStatusCode` fields are
   based on a recent Appwrite Dart SDK generation. Pin `appwrite: ^13.0.0`
   in `pubspec.yaml` and diff against the SDK actually resolved by
   `flutter pub get` before relying on this in production.
2. **Server-side Team membership creation** (`teams.create_membership`
   called with an API key) is assumed to auto-confirm without sending an
   invitation email. Verify this against the Appwrite version you deploy
   to; if it does send an invite, the Admin/Gestionnaire will need to
   click it before the team-scoped read permissions apply, and the
   onboarding UX copy should say so.
3. **Temp password delivery** for a newly created Gestionnaire is
   currently just returned in the function's response body for the Admin
   to relay manually. Once §5.4 (Notifications) exists, route it through
   that instead of displaying/copying a raw password in the app.
4. **E.164 phone formatting** is not enforced/normalized anywhere yet
   (only a loose `+?[0-9]{8,15}` regex in the Bloc). Appwrite's phone-based
   APIs expect E.164 (`+237...`); add normalization before submission once
   a specific input mask/library is chosen — out of scope for a
   regex-only validation constraint.

## Next steps (not part of this generation)

- §5.2 Gestion des entreprises: extend `features/company` to full CRUD +
  activation toggle + subscription-plan association.
- §5.6/5.7 location assignment: a Gestionnaire's `assignedLocationIds` (or
  the inverse, a `gestionnaireId` on `Localisation`) belongs to the
  Localisations feature, not here — don't add it to `UserProfile`.
- Wire real navigation/routing and the actual page UI (forms, layout) —
  Presentation was intentionally generated as controllers + empty
  scaffolds only, per project convention.
