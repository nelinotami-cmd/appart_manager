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

```bash
appwrite databases create-collection \
  --database-id erp_dev_db \
  --collection-id companies \
  --name "Companies" \
  --document-security true \
  --permissions 'read("users")'
  # no create/update/delete permission here on purpose: server-only via functions.

appwrite databases create-string-attribute --database-id erp_dev_db --collection-id companies --key name --size 255 --required true
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id companies --key contactEmail --size 255 --required true
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id companies --key contactPhone --size 32 --required true
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id companies --key address --size 500 --required true
appwrite databases create-enum-attribute --database-id erp_dev_db --collection-id companies --key status --elements "active" "inactive" --required true
appwrite databases create-string-attribute --database-id erp_dev_db --collection-id companies --key subscriptionPlanId --size 64 --required false

appwrite databases create-index --database-id erp_dev_db --collection-id companies --key idx_status --type key --attributes status
```

## 3. Collection: `user_profiles`

```bash
appwrite databases create-collection \
  --database-id erp_dev_db \
  --collection-id user_profiles \
  --name "User Profiles" \
  --document-security true \
  --permissions ''
  # no collection-level permission at all: every read/update grant is set
  # per-document (team-scoped) by the Cloud Functions.

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

## 4. Functions

Each function lives at `functions/<name>/` with `src/main.py` and
`requirements.txt`. Create all six with their real, minimum-needed scopes
baked directly into the command (no separate manual step required):

```bash
appwrite functions create \
  --function-id register-company-and-admin \
  --name "Register Company And Admin" \
  --runtime python-3.12 \
  --execute '["any"]' \
  --scopes '["databases.write","users.write","teams.write"]' \
  --entrypoint src/main.py \
  --timeout 15

appwrite functions create \
  --function-id create-gestionnaire-account \
  --name "Create Gestionnaire Account" \
  --runtime python-3.12 \
  --execute '["users"]' \
  --scopes '["databases.read","databases.write","users.write","teams.write"]' \
  --entrypoint src/main.py \
  --timeout 15

appwrite functions create \
  --function-id reset-password \
  --name "Reset Password (OTP)" \
  --runtime python-3.12 \
  --execute '["users"]' \
  --scopes '["users.write"]' \
  --entrypoint src/main.py \
  --timeout 15

appwrite functions create \
  --function-id update-account-status \
  --name "Update Account Status" \
  --runtime python-3.12 \
  --execute '["users"]' \
  --scopes '["databases.read","databases.write","users.write"]' \
  --entrypoint src/main.py \
  --timeout 15

appwrite functions create \
  --function-id delete-gestionnaire-account \
  --name "Delete Gestionnaire Account" \
  --runtime python-3.12 \
  --execute '["users"]' \
  --scopes '["databases.read","databases.write","users.write"]' \
  --entrypoint src/main.py \
  --timeout 15

appwrite functions create \
  --function-id resolve-login-identifier \
  --name "Resolve Login Identifier" \
  --runtime python-3.12 \
  --execute '["any"]' \
  --scopes '["databases.read"]' \
  --entrypoint src/main.py \
  --timeout 15
```

If your installed CLI version rejects the `--scopes` flag on `create`
(older CLIs only accept it on function *update*, not creation), run the
matching `appwrite functions update --function-id <id> --scopes '[...]'`
right after the `create` call above, using the same scopes array shown
for that function.

Every function needs the same three environment variables, all with real
values for this project (`erp_dev_db`, `companies`, `user_profiles`) —
run all 18 commands once, right after creating the six functions above:

```bash
appwrite functions create-variable --function-id register-company-and-admin --key APPWRITE_DATABASE_ID --value erp_dev_db
appwrite functions create-variable --function-id register-company-and-admin --key APPWRITE_COLLECTION_COMPANIES --value companies
appwrite functions create-variable --function-id register-company-and-admin --key APPWRITE_COLLECTION_USER_PROFILES --value user_profiles

appwrite functions create-variable --function-id create-gestionnaire-account --key APPWRITE_DATABASE_ID --value erp_dev_db
appwrite functions create-variable --function-id create-gestionnaire-account --key APPWRITE_COLLECTION_COMPANIES --value companies
appwrite functions create-variable --function-id create-gestionnaire-account --key APPWRITE_COLLECTION_USER_PROFILES --value user_profiles

appwrite functions create-variable --function-id reset-password --key APPWRITE_DATABASE_ID --value erp_dev_db
appwrite functions create-variable --function-id reset-password --key APPWRITE_COLLECTION_COMPANIES --value companies
appwrite functions create-variable --function-id reset-password --key APPWRITE_COLLECTION_USER_PROFILES --value user_profiles

appwrite functions create-variable --function-id update-account-status --key APPWRITE_DATABASE_ID --value erp_dev_db
appwrite functions create-variable --function-id update-account-status --key APPWRITE_COLLECTION_COMPANIES --value companies
appwrite functions create-variable --function-id update-account-status --key APPWRITE_COLLECTION_USER_PROFILES --value user_profiles

appwrite functions create-variable --function-id delete-gestionnaire-account --key APPWRITE_DATABASE_ID --value erp_dev_db
appwrite functions create-variable --function-id delete-gestionnaire-account --key APPWRITE_COLLECTION_COMPANIES --value companies
appwrite functions create-variable --function-id delete-gestionnaire-account --key APPWRITE_COLLECTION_USER_PROFILES --value user_profiles

appwrite functions create-variable --function-id resolve-login-identifier --key APPWRITE_DATABASE_ID --value erp_dev_db
appwrite functions create-variable --function-id resolve-login-identifier --key APPWRITE_COLLECTION_COMPANIES --value companies
appwrite functions create-variable --function-id resolve-login-identifier --key APPWRITE_COLLECTION_USER_PROFILES --value user_profiles
```

(`reset-password` and `resolve-login-identifier` don't currently read
`APPWRITE_COLLECTION_COMPANIES`, but setting it on every function keeps
the six deployments identical/interchangeable and costs nothing.)

Deploy each function (run from the function's own directory so
`requirements.txt` is picked up):

```bash
cd functions/register-company-and-admin && appwrite functions create-deployment --function-id register-company-and-admin --code . --activate true && cd -
cd functions/create-gestionnaire-account && appwrite functions create-deployment --function-id create-gestionnaire-account --code . --activate true && cd -
cd functions/reset-password && appwrite functions create-deployment --function-id reset-password --code . --activate true && cd -
cd functions/update-account-status && appwrite functions create-deployment --function-id update-account-status --code . --activate true && cd -
cd functions/delete-gestionnaire-account && appwrite functions create-deployment --function-id delete-gestionnaire-account --code . --activate true && cd -
cd functions/resolve-login-identifier && appwrite functions create-deployment --function-id resolve-login-identifier --code . --activate true && cd -
```

## 5. Super Admin (manually created, per project instructions)

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
```

(The Super Admin has no company Team; give it broader read access to all
companies' data via future Super Admin-scoped Cloud Functions, once
section 5.2/5.3 dashboards are implemented — not needed for Auth alone.)

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
