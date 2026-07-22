# Appwrite setup — Auth feature (5.1) + minimal Company support (5.2 stub)

## ⚠️ Naming note before you run anything

Appwrite renamed `Databases > Collections > Documents` to
`Databases > Tables > Rows` in v1.8 (Aug 2025). The `appwrite databases
create-collection` / `create-document` / `create-*-attribute` commands
used below still work — Appwrite kept them fully backwards-compatible and
says they'll keep receiving security patches — but they are now the
**legacy** API. New features only land on the `appwrite tables-db`
equivalents (`create-table`, `create-row`, `create-column`, ...) going
forward, and the Python Cloud Functions in `functions/` currently use the
matching legacy `Databases` SDK service (`databases.create_document`,
etc.), not `TablesDB`.

Since this is a brand-new project (not a legacy one being kept
compatible), the more correct long-term choice is almost certainly to
build on `TablesDB`/`Rows` from the start rather than begin on a
deprecated API. **I have not yet migrated this doc or the Cloud Functions
to TablesDB — say the word and I'll do that rewrite properly** (it
touches every collection/document call in `appwrite_setup.md` and in all
six `functions/*/src/main.py` files, plus the Dart datasources). Until
then, everything below uses the legacy (but still fully functional)
`databases` API so you have a working setup today.

## 0. Project configuration

This project is linked to a real Appwrite project:

```json
{
    "organizationId": "6807fbf1000e6e2884c8",
    "projectId": "6a4dcc99a56bf22ec3a8",
    "projectName": "appart_erp",
    "endpoint": "https://fra.cloud.appwrite.io/v1"
}
```

`appwrite.json` (repo root) already pins `projectId`/`projectName`, so
running any command below from the repo root auto-targets this project —
no `appwrite init project` step needed.

```bash
npm install -g appwrite-cli
appwrite login
appwrite client --endpoint https://fra.cloud.appwrite.io/v1
```

Every command below is written for the **dev** environment, using the
real database id already set in `.env.dev`: **`erp_dev_db`**. There is
nothing left to substitute — copy/paste top to bottom and it runs as-is
against project `appart_erp`. See the "Other environments" section at the
very bottom for what to change when you provision separate `preprod`/
`prod` Appwrite projects later.

Permission model summary (see function source comments for the full
rationale):
- Both collections use **document security** (`--document-security true`)
  and have an **empty collection-level `create` permission** — every
  document is created exclusively by a Cloud Function using the Server
  SDK (API key), so client-forged `role`/`companyId` is impossible.
- Tenant isolation is enforced with one **Appwrite Team per company**
  (`team_id == company_id`). `user_profiles` documents get
  `read(team:<companyId>)` / `update(team:<companyId>/admin)` permissions
  set at creation time inside the functions.

---

## 1. Database

```bash
appwrite databases create \
  --database-id erp_dev_db \
  --name "ERP Appartements Meubles"
```

## 2. Collection: `companies`

**Corrected from an earlier version of this doc**, now that feature 5.2
is actually built: this collection had a blanket `read("users")`
permission, meaning any authenticated user from any company could read
every company's document. Since 5.2 gives Admins real data to look at,
that's no longer acceptable. There is now **no collection-level
permission at all** - every document gets its own per-document
`read(team:<companyId>)` + `read(label:superAdmin)` grants, set inside
`auth.register-company-and-admin` (the only place a company is ever
created - see `CompanyRepository`'s doc comment for why 5.2 has no
separate create resource). Nobody gets direct `update` permission either -
every write goes through a `company.*` Cloud Function resource instead,
because Appwrite permissions are document-level, not field-level, and an
Admin having `update` on the document would also let them flip
`status`/`subscriptionPlanId` directly, which only Super Admin may do.

```bash
appwrite databases create-collection \
  --database-id erp_dev_db \
  --collection-id companies \
  --name "Companies" \
  --document-security true
  # no --permissions flag at all, same reasoning as user_profiles below.

appwrite databases create-string-attribute --database-id erp_dev_db --collection-id companies --key name --size 255 --required true
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id companies --key contactName --size 255 --required true
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id companies --key contactEmail --size 255 --required true
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id companies --key contactPhone --size 32 --required true
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id companies --key address --size 500 --required true
appwrite databases create-enum-attribute --database-id erp_dev_db --collection-id companies --key status --elements "active" "inactive" --required true
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id companies --key subscriptionPlanId --size 64 --required false

appwrite databases create-index --database-id erp_dev_db --collection-id companies --key idx_status --type key --attributes status
appwrite databases create-index --database-id erp_dev_db --collection-id companies --key idx_name_search --type fulltext --attributes name
```

**`contactName` is new** (added while building out 5.2's actual UI - the
mockups treat "contact" as a named person, and the original attribute
set only had email/phone). If you already created the `companies`
collection before this, add it now and backfill existing documents:

```bash
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id companies --key contactName --size 255 --required true --default "REPLACE_ME"
# Then update each existing company document's contactName to something
# real (its Admin's name is a reasonable default, matching what
# auth.register-company-and-admin now sets for new companies).
```

**If you already ran the old version of this doc**, your `companies`
collection currently has `read("users")` set at the collection level and
your existing company document(s) have no per-document permissions at
all (since the old `auth.register-company-and-admin` didn't set any).
Fix both:

```bash
# Remove the old collection-level permission:
appwrite databases update-collection --database-id erp_dev_db --collection-id companies --name "Companies" --document-security true

# Grant the new per-document permissions to any company created before this fix
# (replace <companyId> for each existing company):
appwrite databases update-document --database-id erp_dev_db --collection-id companies --document-id <companyId> --permissions 'read("team:<companyId>")' 'read("label:superAdmin")'
```

## 3. Collection: `subscription_plans`

New for feature 5.3. Unlike `companies`/`user_profiles`, this collection
is **not** tenant-scoped - plans are global catalog data, readable by any
authenticated user (an Admin needs to see their own plan's price/features
in 5.2), writable only through the `subscription.*` Cloud Function
resources (Super Admin only, enforced inside each handler).

```bash
appwrite databases create-collection \
  --database-id erp_dev_db \
  --collection-id subscription_plans \
  --name "Subscription Plans" \
  --document-security true
  # no collection-level permission; each document gets read(users) set
  # explicitly by subscription.create-plan, matching the "readable by any
  # authenticated user" intent without granting anyone a collection-wide
  # blanket permission up front.

appwrite databases create-string-attribute --database-id erp_dev_db --collection-id subscription_plans --key name --size 255 --required true
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id subscription_plans --key description --size 1000 --required true
appwrite databases create-float-attribute --database-id erp_dev_db --collection-id subscription_plans --key monthlyPrice --required true --min 0
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id subscription_plans --key enabledFeatures --size 64 --required false --array true

appwrite databases create-index --database-id erp_dev_db --collection-id subscription_plans --key idx_name_search --type fulltext --attributes name
```

## 4. Collection: `user_profiles`

```bash
appwrite databases create-collection \
  --database-id erp_dev_db \
  --collection-id user_profiles \
  --name "User Profiles" \
  --document-security true
  # no --permissions flag at all: for a variadic flag like this, "zero
  # values" means omitting it, not passing an empty string. Every
  # read/update grant is set per-document (team-scoped) by the Cloud
  # Functions instead.

appwrite databases create-string-attribute --database-id erp_dev_db --collection-id user_profiles --key fullName --size 255 --required true
appwrite databases create-email-attribute  --database-id erp_dev_db --collection-id user_profiles --key email --required true
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id user_profiles --key phone --size 32 --required true
appwrite databases create-enum-attribute   --database-id erp_dev_db --collection-id user_profiles --key role --elements "superAdmin" "admin" "gestionnaire" --required true
appwrite databases create-enum-attribute   --database-id erp_dev_db --collection-id user_profiles --key status --elements "active" "inactive" --required true
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id user_profiles --key createdBy --size 64 --required false

# Relationship: many user_profiles -> one company (one-way is enough;
# Company doesn't need a back-reference for this feature's scope).
appwrite databases create-relationship-attribute \
  --database-id erp_dev_db \
  --collection-id user_profiles \
  --related-collection-id companies \
  --type manyToOne \
  --two-way false \
  --key companyId \
  --on-delete restrict

# Indexes
appwrite databases create-unique-index --database-id erp_dev_db --collection-id user_profiles --key idx_email_unique --attributes email
appwrite databases create-index --database-id erp_dev_db --collection-id user_profiles --key idx_phone --type key --attributes phone
appwrite databases create-index --database-id erp_dev_db --collection-id user_profiles --key idx_role --type key --attributes role
appwrite databases create-index --database-id erp_dev_db --collection-id user_profiles --key idx_fullname_search --type fulltext --attributes fullName
```

> NOTE: `companyId` is a *relationship* attribute (not a plain string), so
> the CLI/console manages its storage; the Flutter mapper
> (`UserProfileMapper._extractRelationId`) already tolerates both the
> plain-id and populated-object shapes Appwrite may return for it.

## 5. Functions

**Before running the `functions create` command below**, run
`appwrite functions create --help` once and confirm `--execute` and
`--scopes` accept space-separated repeated values (as used below), not a
JSON-array string. I've gotten CLI flag *syntax* wrong twice now in this
doc (a wrapper class that didn't exist in the pinned package version,
then a JSON-array-string format for `--scopes` that isn't how this CLI's
variadic flags actually work), so rather than ask you to trust a third
attempt blind: if anything in your `--help` output disagrees with what's
below, go with `--help`, not this doc.

**Project policy: exactly ONE Appwrite Function, ever.** Not just for
Auth — every feature this project adds (Company and Subscription today;
Bookings, Tasks, Notifications, ... later) routes its privileged
server-side operations through this same function, `api`
(`functions/api/src/main.py`), selected by a `resource` field in the
request body (`auth.*`, `company.*`, `subscription.*` today — see the
module docstring at the top of `main.py` for the full current list and
the exact naming convention). **Never create a second function directory
under `functions/`.** This exists to fit under an Appwrite plan's
function-count limit regardless of how many features get built — each
Flutter-side call already sends the right `resource` value automatically
(see `AuthFunctionsRemoteDataSource._executeResource` and its
`CompanyFunctionsRemoteDataSource`/`SubscriptionFunctionsRemoteDataSource`
equivalents), so nothing about the app's behavior depends on how many
features share this one function.

The function's execute permission has to be `any` (the widest any single
resource needs — registration and login-identifier resolution must be
callable by guests), and its scopes are the *union* of every resource's
needs. **Corrected from an earlier version of this doc:** every handler
below calls document-level operations (`create_document`, `get_document`,
`update_document`, `delete_document`, `list_documents`) - these are
gated by the `documents.*` scopes specifically, NOT `databases.*` (which
gates database/collection/schema management operations that nothing in
this function actually performs at runtime). Using `databases.read`/
`databases.write` here - as an earlier version of this doc said to -
silently does nothing useful and produces a `missing scopes
(["documents.write"])` error the first time any handler tries to write a
document:

```bash
appwrite functions create \
  --function-id api \
  --name "API" \
  --runtime python-3.12 \
  --execute any \
  --scopes documents.read documents.write users.write teams.write \
  --entrypoint src/main.py \
  --timeout 15
```

If your installed CLI version rejects the `--scopes` flag on `create`
(older CLIs only accept it on function *update*, not creation), run
`appwrite functions update --function-id api --scopes documents.read documents.write users.write teams.write`
right after the `create` call above. Either way, this can also be set
from Console → Functions → `api` → Settings → Scopes (check
`documents.read` and `documents.write` alongside `users.write` and
`teams.write`) - no redeploy needed for a scope-only change, it takes
effect on the next execution.

`any` execute permission does **not** mean every resource is public —
each handler inside `api/src/main.py` still checks `x-appwrite-user-id`
itself and returns 401/403 for the operations that need an authenticated
Admin/caller (`auth.create-gestionnaire-account`, `auth.reset-password`,
`auth.update-account-status`, `auth.delete-gestionnaire-account`), exactly
as it did as a separate "users"-only function before consolidation. Only
`auth.register-company-and-admin` and `auth.resolve-login-identifier` are
actually meant to be reachable by anyone. Every future resource added to
this function must keep doing its own auth check the same way — the
router does not (and cannot, generically) enforce this for you.

The function needs four environment variables (the subscription_plans
one is new for feature 5.3), set once:

```bash
appwrite functions create-variable --function-id api --key APPWRITE_DATABASE_ID --value erp_dev_db
appwrite functions create-variable --function-id api --key APPWRITE_COLLECTION_COMPANIES --value companies
appwrite functions create-variable --function-id api --key APPWRITE_COLLECTION_USER_PROFILES --value user_profiles
appwrite functions create-variable --function-id api --key APPWRITE_COLLECTION_SUBSCRIPTION_PLANS --value subscription_plans
```

If you already have this function deployed from before 5.3, just add the
one new variable - `_load_env()` in `main.py` will tell you clearly if
it's missing (a 500 with a message naming the exact key) rather than
failing opaquely.

Deploy it (run from the function's own directory so `requirements.txt` is
picked up):

```bash
cd functions/api && appwrite functions create-deployment --function-id api --code . --activate true && cd -
```

Whenever a future feature adds resources to `main.py` (or to a sibling
module under `functions/api/src/` that `main.py` imports — splitting the
file is fine once it gets large; deploying it as a second function is
not), re-run this same `create-deployment` command to push the updated
code — there's still only ever the one `create` command from above, run
once, ever.

## 6. Super Admin (manually created, per project instructions)

The Super Admin is created once, out-of-band, directly via the Appwrite
Console or CLI (NOT through `register-company-and-admin`, which always
creates role `admin`). The command below uses `erp_dev_db` (real) —
replace only the three genuinely-yours values marked `REPLACE_ME`
(email, phone, password/name are person-specific and can't be filled in
for you):

```bash
appwrite users create \
  --user-id super-admin-001 \
  --email REPLACE_ME@yourcompany.cm \
  --phone "+237REPLACE_ME" \
  --password "REPLACE_ME_ChangeImmediately!" \
  --name "Super Admin"

appwrite databases create-document \
  --database-id erp_dev_db \
  --collection-id user_profiles \
  --document-id super-admin-001 \
  --data '{"fullName":"Super Admin","email":"REPLACE_ME@yourcompany.cm","phone":"+237REPLACE_ME","role":"superAdmin","companyId":null,"status":"active","createdBy":null}' \
  --permissions 'read("user:super-admin-001")' 'update("user:super-admin-001")'

# Required as of feature 5.2: every company document grants
# read(label:superAdmin) instead of a blanket collection-level read, so
# the Super Admin's Auth account needs this exact label to actually see
# any company. Without this step, the Super Admin can log in but every
# company (including ones already showing up for other users) will 404
# for them specifically.
appwrite users update-labels --user-id super-admin-001 --labels superAdmin
```

(No company Team for the Super Admin - the `label:superAdmin` grant above
is what gives them cross-tenant read access to every company document
and its Realtime events, instead of team membership.)

## Other environments (preprod / prod)

Everything above targets the single Appwrite project you gave me
(`appart_erp`, id `6a4dcc99a56bf22ec3a8`) and its `erp_dev_db` database.
When you provision separate `preprod`/`prod` Appwrite **projects** under
the same organization (`6807fbf1000e6e2884c8`):

1. `appwrite client --project-id <the new project's id>` (or update
   `appwrite.json` and re-run `appwrite login` against it).
2. Re-run sections 1-5 verbatim, with every `erp_dev_db` replaced by
   `erp_preprod_db` or `erp_prod_db` respectively (matching
   `.env.preprod` / `.env.prod`).
3. Function scopes/execute permissions/env-var keys are identical across
   environments — only the `--database-id`/`APPWRITE_DATABASE_ID` values
   and the target project change.
