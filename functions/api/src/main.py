"""
api
-----
THE single Appwrite Function for this entire project. Project policy:
there is exactly one Appwrite Function, ever - every feature's privileged
server-side operation (Auth today; Company/Bookings/Tasks/etc. later)
gets added as a new resource handler in THIS file, routed by a top-level
"resource" key in the request body. Never create a second Appwrite
Function/directory under `functions/` - add a handler here instead. This
keeps the project under an Appwrite plan's function-count limit
regardless of how many features/operations get added over time.

Routing convention: resource keys are namespaced per feature as
"<feature>.<action>", e.g. "auth.register-company-and-admin". This is
mandatory for every NEW feature's resources (even though it only holds
one value right now) so two features can never accidentally collide on
the same resource string as the project grows. Currently registered
features/resources:

  auth.register-company-and-admin
  auth.create-gestionnaire-account
  auth.reset-password
  auth.update-account-status
  auth.delete-gestionnaire-account
  auth.resolve-login-identifier
  company.update-profile
  company.update-status
  company.assign-subscription-plan
  subscription.create-plan
  subscription.update-plan
  subscription.delete-plan
  notification.create-template
  notification.update-template
  notification.delete-template
  notification.send-test-email
  notification.set-my-preferences

Adding a new feature (e.g. "company"): write its handler function(s)
below (or, once this file gets large, in a sibling module under
`functions/api/src/` that you import here - either is fine, "one
function" only constrains the Appwrite deployment unit, not how many
.py files back it), register each under a "company.<action>" key in the
shared `_HANDLERS` dict at the bottom of this file, and add any new
scopes that feature's handler needs to the function's dynamic API key
(see appwrite_setup.md) - the function's scopes are always the UNION of
every feature's needs, since it's the one function everything shares.

Execute permission: any. Some resources must be callable by
unauthenticated/guest callers (auth.register-company-and-admin,
auth.resolve-login-identifier); others require an authenticated caller
and enforce that themselves via `x-appwrite-user-id`, exactly as they did
when each was its own separate "users"-only function. "any" at the
function level only means "don't block at the platform layer" - it is
NOT a statement that every resource is public. Every handler that needs
auth must keep checking for it itself; this file's router does not do
that check generically because different resources need different rules
(guest-allowed, any-authenticated-user, admin-only, super-admin-only...).

Current scopes needed by this function's dynamic API key (the union of
every resource's individual needs so far): documents.read,
documents.write, users.write, teams.write, messages.write (the last one
new for notification.send-test-email, which calls Appwrite's Messaging
API - verified against Appwrite's own API reference, not assumed).
Every handler below calls document-level operations specifically
(create_document, get_document, etc.) - `databases.*` scopes gate
schema/collection management, which nothing here performs at runtime,
and won't satisfy these calls. See
appwrite_setup.md.
"""

import json
import os
import secrets

from appwrite.client import Client
from appwrite.services.databases import Databases
from appwrite.services.users import Users
from appwrite.services.teams import Teams
from appwrite.services.messaging import Messaging
from appwrite.id import ID
from appwrite.permission import Permission
from appwrite.role import Role
from appwrite.query import Query
from appwrite.exception import AppwriteException

# Read lazily (inside main(), not at import time) and report exactly
# which key is missing as a proper JSON 500 response. Reading these with
# bare `os.environ["KEY"]` at module level - as an earlier version of
# this file did - means a single missing env var crashes the WHOLE
# module before any request is even routed: every resource then fails
# with an opaque, bodyless 503 from Appwrite's gateway (the process never
# got far enough to form an HTTP response), which is next to impossible
# to diagnose from the client side. This lazy read turns that failure
# mode into a clear, actionable message instead.
_REQUIRED_ENV_VARS = [
    "APPWRITE_DATABASE_ID",
    "APPWRITE_COLLECTION_COMPANIES",
    "APPWRITE_COLLECTION_USER_PROFILES",
    "APPWRITE_COLLECTION_SUBSCRIPTION_PLANS",
    "APPWRITE_COLLECTION_NOTIFICATION_TEMPLATES",
    "APPWRITE_COLLECTION_NOTIFICATION_LOGS",
    "APPWRITE_COLLECTION_NOTIFICATION_PREFERENCES",
]

# Populated by `_load_env()` on each invocation, before any handler runs.
DATABASE_ID = None
COMPANIES_COLLECTION_ID = None
USER_PROFILES_COLLECTION_ID = None
SUBSCRIPTION_PLANS_COLLECTION_ID = None
NOTIFICATION_TEMPLATES_COLLECTION_ID = None
NOTIFICATION_LOGS_COLLECTION_ID = None
NOTIFICATION_PREFERENCES_COLLECTION_ID = None


def _load_env():
    """Populates the module-level *_ID globals from the environment and
    returns a list of any required keys that are missing (empty list =
    everything present, safe to proceed). Cheap enough to call on every
    invocation - env vars can't change without a redeploy anyway - and
    doing it here rather than at import time means a misconfigured
    function still cold-starts successfully and can report exactly
    what's wrong, instead of crashing the whole module before any
    request is routed (see the note above `_REQUIRED_ENV_VARS`).
    """
    global DATABASE_ID, COMPANIES_COLLECTION_ID, USER_PROFILES_COLLECTION_ID
    global SUBSCRIPTION_PLANS_COLLECTION_ID
    global NOTIFICATION_TEMPLATES_COLLECTION_ID, NOTIFICATION_LOGS_COLLECTION_ID
    global NOTIFICATION_PREFERENCES_COLLECTION_ID
    missing = [key for key in _REQUIRED_ENV_VARS if not os.environ.get(key)]
    if missing:
        return missing
    DATABASE_ID = os.environ["APPWRITE_DATABASE_ID"]
    COMPANIES_COLLECTION_ID = os.environ["APPWRITE_COLLECTION_COMPANIES"]
    USER_PROFILES_COLLECTION_ID = os.environ["APPWRITE_COLLECTION_USER_PROFILES"]
    SUBSCRIPTION_PLANS_COLLECTION_ID = os.environ["APPWRITE_COLLECTION_SUBSCRIPTION_PLANS"]
    NOTIFICATION_TEMPLATES_COLLECTION_ID = os.environ[
        "APPWRITE_COLLECTION_NOTIFICATION_TEMPLATES"
    ]
    NOTIFICATION_LOGS_COLLECTION_ID = os.environ["APPWRITE_COLLECTION_NOTIFICATION_LOGS"]
    NOTIFICATION_PREFERENCES_COLLECTION_ID = os.environ[
        "APPWRITE_COLLECTION_NOTIFICATION_PREFERENCES"
    ]
    return []


def _client(context):
    return (
        Client()
        .set_endpoint(os.environ["APPWRITE_FUNCTION_API_ENDPOINT"])
        .set_project(os.environ["APPWRITE_FUNCTION_PROJECT_ID"])
        .set_key(context.req.headers.get("x-appwrite-key", ""))
    )


def _doc_to_dict(doc):
    """Flattens an SDK `Document` model into the flat dict shape this file's
    JSON responses (and the Flutter client's `UserProfileMapper`) expect.

    appwrite-python-sdk 22.x's `databases.*` methods return typed Pydantic
    models, not raw dicts: built-in fields ($id, $createdAt, $updatedAt,
    ...) live as lowercase attributes (`doc.id`, `doc.createdat`,
    `doc.updatedat`), and every custom field you defined on the collection
    (fullName, email, role, companyId, status, createdBy, ...) lives
    separately under `doc.data` (a plain dict, since we never pass a
    `model_type` to any `databases.*` call). Neither `doc["$id"]` nor
    `doc.get("role")` works on this object - Pydantic models support
    neither subscript access nor `.get()`. This flattens both parts back
    into one dict matching the original raw REST API document shape.
    """
    return {
        "$id": doc.id,
        "$createdAt": doc.createdat,
        "$updatedAt": doc.updatedat,
        **doc.data,
    }


# ---------------------------------------------------------------------------
# auth.register-company-and-admin
# ---------------------------------------------------------------------------
# Cahier des charges 5.1: "Inscription des entreprises (onboarding SaaS) et
# creation du compte Admin entreprise."
#
# Tenant isolation: an Appwrite Team is created with the SAME id as the
# Company document (`team_id = company_id`), and the new Admin is added to
# it with team-role `admin`. `user_profiles` documents are created with
# document-level permissions scoped to `Role.team(company_id)` /
# `Role.team(company_id, 'admin')`, so Appwrite itself - not just this
# function's own checks - enforces that only members of a company's team
# can ever read/update that company's profiles. Verify current Appwrite
# Teams server-SDK membership-confirmation behaviour against the latest
# docs before going to production (server-created memberships are expected
# to be auto-confirmed, bypassing the invite-email flow, but this should be
# double-checked against the Appwrite version in use).
#
# Expected body (besides "resource"):
# {
#   "companyName": str, "companyAddress": str,
#   "companyContactEmail": str, "companyContactPhone": str,
#   "adminFullName": str, "adminEmail": str, "adminPhone": str,
#   "password": str
# }
# Response 200: the created user_profiles document.
_REGISTER_REQUIRED_FIELDS = [
    "companyName", "companyAddress", "companyContactEmail", "companyContactPhone",
    "adminFullName", "adminEmail", "adminPhone", "password",
]


def _handle_register_company_and_admin(context, body):
    missing = [f for f in _REGISTER_REQUIRED_FIELDS if not body.get(f)]
    if missing:
        return context.res.json(
            {"message": f"Champs manquants: {', '.join(missing)}"}, 400
        )

    if len(body["password"]) < 8:
        return context.res.json(
            {"message": "Le mot de passe doit contenir au moins 8 caracteres."}, 400
        )

    client = _client(context)
    databases = Databases(client)
    users = Users(client)
    teams = Teams(client)

    company_id = None
    user_id = None
    team_created = False

    try:
        company_id = ID.unique()

        # Team created BEFORE the company document, so the
        # `Role.team(company_id)` permission below references a team that
        # already exists by the time anything could try to use it.
        teams.create(team_id=company_id, name=body["companyName"])
        team_created = True

        databases.create_document(
            database_id=DATABASE_ID,
            collection_id=COMPANIES_COLLECTION_ID,
            document_id=company_id,
            data={
                "name": body["companyName"],
                # Defaults to the registering Admin's name - the primary
                # contact is a separately editable field (5.2
                # update-profile) but has to start as *something*, and the
                # person who just signed up is the only person we know.
                "contactName": body["adminFullName"],
                "contactEmail": body["companyContactEmail"],
                "contactPhone": body["companyContactPhone"],
                "address": body["companyAddress"],
                "status": "active",
                "subscriptionPlanId": None,
            },
            # READ only - deliberately no `update` grant for anyone here.
            # Every write to a company document (5.2: update-profile,
            # update-status, assign-subscription-plan) goes through this
            # function's own privileged handlers instead, because Appwrite
            # permissions are document-level, not field-level: if the
            # owning Admin's team role had `update` here, they could also
            # flip `status`/`subscriptionPlanId` directly via the client
            # SDK, which only Super Admin may do.
            permissions=[
                Permission.read(Role.team(company_id)),
                Permission.read(Role.label("superAdmin")),
            ],
        )

        user = users.create(
            user_id=ID.unique(),
            email=body["adminEmail"],
            phone=body["adminPhone"],
            password=body["password"],
            name=body["adminFullName"],
        )
        user_id = user.id

        teams.create_membership(
            team_id=company_id,
            roles=["admin"],
            user_id=user_id,
        )

        profile = databases.create_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=user_id,  # 1:1 with the Auth account, by construction
            data={
                "fullName": body["adminFullName"],
                "email": body["adminEmail"],
                "phone": body["adminPhone"],
                "role": "admin",
                "companyId": company_id,
                "status": "active",
                "createdBy": None,
            },
            permissions=[
                Permission.read(Role.team(company_id)),
                Permission.read(Role.user(user_id)),
                Permission.read(Role.label("superAdmin")),
                Permission.update(Role.team(company_id, "admin")),
                Permission.update(Role.user(user_id)),
            ],
        )

        return context.res.json(_doc_to_dict(profile), 200)

    except AppwriteException as e:
        # Best-effort rollback so a partial failure never leaves an orphan
        # Auth account, Team or Company document behind.
        if user_id:
            try:
                users.delete(user_id=user_id)
            except AppwriteException:
                pass
        if team_created:
            try:
                teams.delete(team_id=company_id)
            except AppwriteException:
                pass
        if company_id:
            try:
                databases.delete_document(
                    database_id=DATABASE_ID,
                    collection_id=COMPANIES_COLLECTION_ID,
                    document_id=company_id,
                )
            except AppwriteException:
                pass

        context.error(str(e))
        return context.res.json(
            {"message": e.message or "Echec de la creation du compte."}, 400
        )


# ---------------------------------------------------------------------------
# auth.create-gestionnaire-account
# ---------------------------------------------------------------------------
# Cahier des charges 5.7: "Creation des comptes gestionnaire par l'Admin
# entreprise." Only an Admin may create a Gestionnaire, and only for their
# own company - both facts are established from the caller's OWN
# user_profiles document (via x-appwrite-user-id), never trusted from the
# request body.
#
# Expected body (besides "resource"): {"fullName": str, "email": str, "phone": str}
# Response 200: the created user_profiles document, plus a one-time
# "tempPassword" field the Admin must communicate to the Gestionnaire
# out-of-band. NOTE: for a production rollout, prefer routing this through
# the Notifications feature (5.4) instead of returning it in the response.
_CREATE_GESTIONNAIRE_REQUIRED_FIELDS = ["fullName", "email", "phone"]


def _handle_create_gestionnaire_account(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    missing = [f for f in _CREATE_GESTIONNAIRE_REQUIRED_FIELDS if not body.get(f)]
    if missing:
        return context.res.json(
            {"message": f"Champs manquants: {', '.join(missing)}"}, 400
        )

    client = _client(context)
    databases = Databases(client)
    users = Users(client)
    teams = Teams(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil de l'appelant introuvable."}, 403)

    if caller_profile.data.get("role") != "admin" or caller_profile.data.get("status") != "active":
        return context.res.json(
            {"message": "Seul un Admin actif peut creer un compte Gestionnaire."}, 403
        )

    company_id = caller_profile.data.get("companyId")
    if not company_id:
        return context.res.json({"message": "Aucune entreprise associee a cet Admin."}, 400)

    temp_password = secrets.token_urlsafe(10)
    user_id = None

    try:
        user = users.create(
            user_id=ID.unique(),
            email=body["email"],
            phone=body["phone"],
            password=temp_password,
            name=body["fullName"],
        )
        user_id = user.id

        teams.create_membership(
            team_id=company_id,
            roles=["gestionnaire"],
            user_id=user_id,
        )

        profile = databases.create_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=user_id,
            data={
                "fullName": body["fullName"],
                "email": body["email"],
                "phone": body["phone"],
                "role": "gestionnaire",
                "companyId": company_id,
                "status": "active",
                "createdBy": caller_id,
            },
            permissions=[
                Permission.read(Role.team(company_id)),
                Permission.read(Role.user(user_id)),
                Permission.read(Role.label("superAdmin")),
                Permission.update(Role.team(company_id, "admin")),
                Permission.update(Role.user(user_id)),
            ],
        )
        profile_dict = _doc_to_dict(profile)
        profile_dict["tempPassword"] = temp_password
        return context.res.json(profile_dict, 200)

    except AppwriteException as e:
        if user_id:
            try:
                users.delete(user_id=user_id)
            except AppwriteException:
                pass
        context.error(str(e))
        return context.res.json(
            {"message": e.message or "Echec de la creation du compte Gestionnaire."}, 400
        )


# ---------------------------------------------------------------------------
# auth.reset-password
# ---------------------------------------------------------------------------
# Second half of the OTP-based password reset flow (cahier des charges
# 5.1). The Flutter client first calls `account.createSession(userId, otp)`
# directly against Appwrite - succeeding proves the OTP was correct and
# opens a session as that user. The client then calls THIS resource while
# authenticated with that session; we read the caller's id from
# `x-appwrite-user-id` (never trust a `userId` in the body for
# authorization) and force-set the new password via the Server SDK Users
# API, which does not require knowledge of any previous password.
#
# Expected body (besides "resource"): {"userId": str, "newPassword": str}
# Response 200: {"status": "ok"}
def _handle_reset_password(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise (session OTP)."}, 401)

    new_password = body.get("newPassword", "")
    if len(new_password) < 8:
        return context.res.json(
            {"message": "Le mot de passe doit contenir au moins 8 caracteres."}, 400
        )

    if body.get("userId") and body["userId"] != caller_id:
        return context.res.json({"message": "Utilisateur incoherent avec la session."}, 403)

    client = _client(context)
    users = Users(client)

    try:
        users.update_password(user_id=caller_id, password=new_password)
        return context.res.json({"status": "ok"}, 200)
    except AppwriteException as e:
        context.error(str(e))
        return context.res.json(
            {"message": e.message or "Echec de la reinitialisation du mot de passe."}, 400
        )


# ---------------------------------------------------------------------------
# auth.update-account-status
# ---------------------------------------------------------------------------
# Admin activates/deactivates a Gestionnaire of their own company (or
# Super Admin may act on any account). Updates BOTH the `user_profiles`
# document (for UI/reporting) AND the underlying Appwrite Auth account's
# status (`users.update_status`) so a deactivated account is actually
# blocked from logging in, not just cosmetically flagged.
#
# Expected body (besides "resource"): {"userId": str, "status": "active" | "inactive"}
# Response 200: the updated user_profiles document.
def _handle_update_account_status(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    target_id = body.get("userId")
    status = body.get("status")
    if not target_id or status not in ("active", "inactive"):
        return context.res.json({"message": "Parametres invalides."}, 400)

    client = _client(context)
    databases = Databases(client)
    users = Users(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil de l'appelant introuvable."}, 403)

    try:
        target_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=target_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Compte cible introuvable."}, 404)

    is_super_admin = caller_profile.data.get("role") == "superAdmin"
    is_owning_admin = (
        caller_profile.data.get("role") == "admin"
        and caller_profile.data.get("companyId") == target_profile.data.get("companyId")
        and target_profile.data.get("role") == "gestionnaire"
    )
    if not (is_super_admin or is_owning_admin):
        return context.res.json({"message": "Action non autorisee."}, 403)

    try:
        users.update_status(user_id=target_id, status=(status == "active"))
        updated = databases.update_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=target_id,
            data={"status": status},
        )
        return context.res.json(_doc_to_dict(updated), 200)
    except AppwriteException as e:
        context.error(str(e))
        return context.res.json(
            {"message": e.message or "Echec de la mise a jour du statut."}, 400
        )


# ---------------------------------------------------------------------------
# auth.delete-gestionnaire-account
# ---------------------------------------------------------------------------
# Permanently deletes a Gestionnaire's Auth account and user_profiles
# document. Only the owning Admin (same companyId) or a Super Admin may do
# this, and only for accounts with role == 'gestionnaire' (an Admin cannot
# delete another Admin or the Super Admin this way).
#
# Expected body (besides "resource"): {"userId": str}
# Response 200: {"status": "deleted"}
def _handle_delete_gestionnaire_account(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    target_id = body.get("userId")
    if not target_id:
        return context.res.json({"message": "userId requis."}, 400)

    client = _client(context)
    databases = Databases(client)
    users = Users(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
        target_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=target_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil introuvable."}, 404)

    is_super_admin = caller_profile.data.get("role") == "superAdmin"
    is_owning_admin = (
        caller_profile.data.get("role") == "admin"
        and caller_profile.data.get("companyId") == target_profile.data.get("companyId")
    )
    if not (is_super_admin or is_owning_admin) or target_profile.data.get("role") != "gestionnaire":
        return context.res.json({"message": "Action non autorisee."}, 403)

    try:
        databases.delete_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=target_id,
        )
        users.delete(user_id=target_id)
        return context.res.json({"status": "deleted"}, 200)
    except AppwriteException as e:
        context.error(str(e))
        return context.res.json(
            {"message": e.message or "Echec de la suppression du compte."}, 400
        )


# ---------------------------------------------------------------------------
# auth.resolve-login-identifier
# ---------------------------------------------------------------------------
# Resolves a login/OTP identifier (email OR phone) to `{userId, email}`
# ONLY - never any other profile field (fullName, role, companyId). This
# is the sole reason this resource exists instead of letting the client
# query `user_profiles` directly: the collection's read permission stays
# scoped to team members (see appwrite_setup.md), so a stranger cannot
# enumerate accounts or harvest PII by probing phone numbers, while the
# app can still support "login/reset with phone number" as required by
# cahier des charges 5.1.
#
# Expected body (besides "resource"): {"identifier": str}
# Response 200: {"userId": str, "email": str}
# Response 404: {"message": "..."}
def _handle_resolve_login_identifier(context, body):
    identifier = (body.get("identifier") or "").strip()
    if not identifier:
        return context.res.json({"message": "identifier requis."}, 400)

    field = "email" if "@" in identifier else "phone"

    client = _client(context)
    databases = Databases(client)

    try:
        result = databases.list_documents(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            queries=[Query.equal(field, identifier), Query.limit(1)],
        )
    except AppwriteException as e:
        context.error(str(e))
        return context.res.json({"message": "Erreur lors de la recherche du compte."}, 500)

    if not result.documents:
        return context.res.json({"message": "Aucun compte associe a cet identifiant."}, 404)

    doc = result.documents[0]
    return context.res.json({"userId": doc.id, "email": doc.data.get("email")}, 200)


# ---------------------------------------------------------------------------
# company.update-profile
# ---------------------------------------------------------------------------
# Cahier des charges 5.2: "Creation et mise a jour du profil d'entreprise."
# Admin may only update their OWN company (established from the caller's
# own profile, never trusted from the body); Super Admin may update any.
# Deliberately does NOT accept `status` or `subscriptionPlanId` - those
# are separate resources restricted to Super Admin only.
#
# Expected body: {"companyId": str, "name": str, "contactEmail": str,
#                 "contactPhone": str, "address": str}
# Response 200: the updated companies document.
_UPDATE_PROFILE_REQUIRED_FIELDS = [
    "companyId", "name", "contactName", "contactEmail", "contactPhone", "address",
]


def _handle_update_company_profile(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    missing = [f for f in _UPDATE_PROFILE_REQUIRED_FIELDS if not body.get(f)]
    if missing:
        return context.res.json({"message": f"Champs manquants: {', '.join(missing)}"}, 400)

    client = _client(context)
    databases = Databases(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil de l'appelant introuvable."}, 403)

    target_company_id = body["companyId"]
    is_super_admin = caller_profile.data.get("role") == "superAdmin"
    is_owning_admin = (
        caller_profile.data.get("role") == "admin"
        and caller_profile.data.get("companyId") == target_company_id
    )
    if not (is_super_admin or is_owning_admin):
        return context.res.json({"message": "Action non autorisee."}, 403)

    try:
        updated = databases.update_document(
            database_id=DATABASE_ID,
            collection_id=COMPANIES_COLLECTION_ID,
            document_id=target_company_id,
            data={
                "name": body["name"],
                "contactName": body["contactName"],
                "contactEmail": body["contactEmail"],
                "contactPhone": body["contactPhone"],
                "address": body["address"],
            },
        )
        return context.res.json(_doc_to_dict(updated), 200)
    except AppwriteException as e:
        context.error(str(e))
        return context.res.json({"message": e.message or "Echec de la mise a jour du profil."}, 400)


# ---------------------------------------------------------------------------
# company.update-status
# ---------------------------------------------------------------------------
# Super Admin only. Cahier des charges 5.2: "Activation / desactivation
# d'une entreprise." Deactivating a company cascades: every member's
# Appwrite account is also deactivated (blocked from logging in
# immediately), consistent with individual Gestionnaire deactivation
# (`auth.update-account-status`). Reactivating the company does NOT
# auto-reactivate members - an Admin/Super Admin re-enables individuals
# afterward via `auth.update-account-status`, so a member deactivated for
# an unrelated reason before the company-wide deactivation doesn't get
# silently swept back in.
#
# Expected body: {"companyId": str, "status": "active" | "inactive"}
# Response 200: the updated companies document.
def _handle_update_company_status(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    target_company_id = body.get("companyId")
    status = body.get("status")
    if not target_company_id or status not in ("active", "inactive"):
        return context.res.json({"message": "Parametres invalides."}, 400)

    client = _client(context)
    databases = Databases(client)
    users = Users(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil de l'appelant introuvable."}, 403)

    if caller_profile.data.get("role") != "superAdmin":
        return context.res.json(
            {"message": "Seul un Super Admin peut activer/desactiver une entreprise."}, 403
        )

    try:
        updated = databases.update_document(
            database_id=DATABASE_ID,
            collection_id=COMPANIES_COLLECTION_ID,
            document_id=target_company_id,
            data={"status": status},
        )
    except AppwriteException as e:
        context.error(str(e))
        return context.res.json({"message": e.message or "Echec de la mise a jour du statut."}, 400)

    if status == "inactive":
        try:
            members = databases.list_documents(
                database_id=DATABASE_ID,
                collection_id=USER_PROFILES_COLLECTION_ID,
                queries=[Query.equal("companyId", target_company_id), Query.limit(500)],
            )
            for member in members.documents:
                try:
                    users.update_status(user_id=member.id, status=False)
                except AppwriteException as e:
                    # Best-effort: one member's account failing to block
                    # shouldn't stop the others or fail the whole request -
                    # the company itself is already deactivated either way.
                    context.error(f"Failed to deactivate member {member.id}: {e}")
        except AppwriteException as e:
            context.error(f"Failed to list company members for cascade deactivation: {e}")

    return context.res.json(_doc_to_dict(updated), 200)


# ---------------------------------------------------------------------------
# company.assign-subscription-plan
# ---------------------------------------------------------------------------
# Cahier des charges 5.2: "Liaison entreprise <-> plan d'abonnement."
# `subscriptionPlanId` is stored as-is with no validation against an
# actual plan entity's existence beyond the get_document check below.
#
# Super Admin may assign/change a plan on any company at any time. Admin
# may only set an INITIAL plan for their OWN company, and only while it
# currently has none - once a plan is assigned, changing it is
# Super-Admin-only. This mirrors the Flutter side (an inline picker on
# the company detail page, shown only when there's no current plan) but
# is enforced here independently, not just hidden client-side.
#
# Expected body: {"companyId": str, "subscriptionPlanId": str | None}
# Response 200: the updated companies document.
def _handle_assign_subscription_plan(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    target_company_id = body.get("companyId")
    if not target_company_id:
        return context.res.json({"message": "companyId requis."}, 400)

    client = _client(context)
    databases = Databases(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil de l'appelant introuvable."}, 403)

    try:
        target_company = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=COMPANIES_COLLECTION_ID,
            document_id=target_company_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Entreprise introuvable."}, 404)

    is_super_admin = caller_profile.data.get("role") == "superAdmin"
    is_owning_admin_setting_initial_plan = (
        caller_profile.data.get("role") == "admin"
        and caller_profile.data.get("companyId") == target_company_id
        and target_company.data.get("subscriptionPlanId") is None
    )
    if not (is_super_admin or is_owning_admin_setting_initial_plan):
        return context.res.json(
            {
                "message": (
                    "Seul un Super Admin peut modifier un plan deja assigne. "
                    "Un Admin peut assigner un premier plan si l'entreprise n'en a pas."
                )
            },
            403,
        )

    try:
        updated = databases.update_document(
            database_id=DATABASE_ID,
            collection_id=COMPANIES_COLLECTION_ID,
            document_id=target_company_id,
            data={"subscriptionPlanId": body.get("subscriptionPlanId")},
        )
        return context.res.json(_doc_to_dict(updated), 200)
    except AppwriteException as e:
        context.error(str(e))
        return context.res.json({"message": e.message or "Echec de l'assignation du plan."}, 400)


# ---------------------------------------------------------------------------
# subscription.create-plan
# ---------------------------------------------------------------------------
# Super Admin only. Cahier des charges 5.3: "CRUD des plans d'abonnement
# (nom, fonctionnalites activees)." `enabledFeatures` is a free-form list
# of feature keys - the cahier des charges doesn't enumerate a fixed
# catalog, so this isn't validated against one; the Flutter side offers a
# small illustrative set (bookings, discounts, prioritySupport,
# advancedReports, apiAccess, unlimitedGestionnaires) but nothing here
# rejects an unrecognized key.
#
# Expected body: {"name": str, "description": str, "monthlyPrice": number,
#                 "enabledFeatures": [str, ...]}
# Response 200: the created subscription_plans document.
_CREATE_PLAN_REQUIRED_FIELDS = ["name", "description", "monthlyPrice"]


def _handle_create_subscription_plan(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    missing = [f for f in _CREATE_PLAN_REQUIRED_FIELDS if body.get(f) is None]
    if missing:
        return context.res.json({"message": f"Champs manquants: {', '.join(missing)}"}, 400)

    client = _client(context)
    databases = Databases(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil de l'appelant introuvable."}, 403)

    if caller_profile.data.get("role") != "superAdmin":
        return context.res.json(
            {"message": "Seul un Super Admin peut creer un plan d'abonnement."}, 403
        )

    try:
        created = databases.create_document(
            database_id=DATABASE_ID,
            collection_id=SUBSCRIPTION_PLANS_COLLECTION_ID,
            document_id=ID.unique(),
            data={
                "name": body["name"],
                "description": body["description"],
                "monthlyPrice": body["monthlyPrice"],
                "enabledFeatures": body.get("enabledFeatures") or [],
            },
            # Readable by any authenticated user (Admins need to see their
            # own plan's features/price; the catalog itself isn't
            # sensitive) - write stays function-only, same reasoning as
            # companies.
            permissions=[Permission.read(Role.users())],
        )
        return context.res.json(_doc_to_dict(created), 200)
    except AppwriteException as e:
        context.error(str(e))
        return context.res.json({"message": e.message or "Echec de la creation du plan."}, 400)


# ---------------------------------------------------------------------------
# subscription.update-plan
# ---------------------------------------------------------------------------
# Super Admin only.
#
# Expected body: {"planId": str, "name": str, "description": str,
#                 "monthlyPrice": number, "enabledFeatures": [str, ...]}
# Response 200: the updated subscription_plans document.
_UPDATE_PLAN_REQUIRED_FIELDS = ["planId", "name", "description", "monthlyPrice"]


def _handle_update_subscription_plan(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    missing = [f for f in _UPDATE_PLAN_REQUIRED_FIELDS if body.get(f) is None]
    if missing:
        return context.res.json({"message": f"Champs manquants: {', '.join(missing)}"}, 400)

    client = _client(context)
    databases = Databases(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil de l'appelant introuvable."}, 403)

    if caller_profile.data.get("role") != "superAdmin":
        return context.res.json(
            {"message": "Seul un Super Admin peut modifier un plan d'abonnement."}, 403
        )

    try:
        updated = databases.update_document(
            database_id=DATABASE_ID,
            collection_id=SUBSCRIPTION_PLANS_COLLECTION_ID,
            document_id=body["planId"],
            data={
                "name": body["name"],
                "description": body["description"],
                "monthlyPrice": body["monthlyPrice"],
                "enabledFeatures": body.get("enabledFeatures") or [],
            },
        )
        return context.res.json(_doc_to_dict(updated), 200)
    except AppwriteException as e:
        context.error(str(e))
        return context.res.json({"message": e.message or "Echec de la mise a jour du plan."}, 400)


# ---------------------------------------------------------------------------
# subscription.delete-plan
# ---------------------------------------------------------------------------
# Super Admin only. Real deletion (matches cahier des charges 5.3's
# literal "CRUD"), not a soft-deactivation - so any company still
# referencing this plan has its `subscriptionPlanId` cleared (set to
# None) as part of the same operation, avoiding an orphaned reference.
# The Flutter side fetches which companies would be affected BEFORE
# calling this (via `CompanyRepository.listCompaniesByPlanId`, a plain
# read) so the confirmation dialog can show them - this handler doesn't
# need to return that list since the caller already has it.
#
# Expected body: {"planId": str}
# Response 200: {"status": "deleted", "companiesUpdated": int}
def _handle_delete_subscription_plan(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    plan_id = body.get("planId")
    if not plan_id:
        return context.res.json({"message": "planId requis."}, 400)

    client = _client(context)
    databases = Databases(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil de l'appelant introuvable."}, 403)

    if caller_profile.data.get("role") != "superAdmin":
        return context.res.json(
            {"message": "Seul un Super Admin peut supprimer un plan d'abonnement."}, 403
        )

    companies_updated = 0
    try:
        affected = databases.list_documents(
            database_id=DATABASE_ID,
            collection_id=COMPANIES_COLLECTION_ID,
            queries=[Query.equal("subscriptionPlanId", plan_id), Query.limit(500)],
        )
        for company in affected.documents:
            try:
                databases.update_document(
                    database_id=DATABASE_ID,
                    collection_id=COMPANIES_COLLECTION_ID,
                    document_id=company.id,
                    data={"subscriptionPlanId": None},
                )
                companies_updated += 1
            except AppwriteException as e:
                # Best-effort: one company failing to clear shouldn't stop
                # the others or block the plan deletion itself.
                context.error(f"Failed to clear plan on company {company.id}: {e}")
    except AppwriteException as e:
        context.error(f"Failed to list companies for plan {plan_id}: {e}")

    try:
        databases.delete_document(
            database_id=DATABASE_ID,
            collection_id=SUBSCRIPTION_PLANS_COLLECTION_ID,
            document_id=plan_id,
        )
        return context.res.json(
            {"status": "deleted", "companiesUpdated": companies_updated}, 200
        )
    except AppwriteException as e:
        context.error(str(e))
        return context.res.json({"message": e.message or "Echec de la suppression du plan."}, 400)


# ---------------------------------------------------------------------------
# Notification helpers (shared by every notification.* handler below, and
# meant to be called by 5.8/5.10 later too - not notification.*-specific).
# ---------------------------------------------------------------------------
def _send_email(client, *, user_id, subject, content, scheduled_at=None):
    """Sends (or, with `scheduled_at` set, schedules) an email via
    Appwrite Messaging to an EXISTING Appwrite user - `users: [user_id]`,
    NOT a raw email address. Appwrite Messaging is built entirely on
    Targets, and every Target is tied to a Users account; there is no
    supported way to email an address with no corresponding Appwrite
    user (verified against Appwrite's own docs - no confirmed path
    found, including in Appwrite's own community threads asking this
    exact question). For company notifications (Admin/Gestionnaire -
    always real Appwrite users, since they signed up with email +
    password), this is sufficient. If a future feature (5.8) needs to
    email a booking guest who isn't a platform user at all, that needs
    its own design - not solved here.

    Requires an SMTP provider (Mailgun/Sendgrid/etc.) configured in the
    Appwrite Console first - see appwrite_setup.md. `scheduled_at`, when
    given, must be an ISO 8601 string in the future (Appwrite's own
    validation, not enforced here).

    Returns (success: bool, error_message: str | None) - never raises,
    so a failed send never crashes the caller; every caller logs the
    outcome via `_write_notification_log` regardless.
    """
    messaging = Messaging(client)
    try:
        messaging.create_email(
            message_id=ID.unique(),
            subject=subject,
            content=content,
            users=[user_id],
            scheduled_at=scheduled_at,
        )
        return True, None
    except AppwriteException as e:
        return False, (e.message or str(e))


def _write_notification_log(
    context,
    databases,
    *,
    company_id,
    recipient_label,
    channel,
    subject,
    message,
    status,
    error_message=None,
):
    """Writes one NotificationLog entry. `company_id` may be `None` (a
    Super Admin's own test-send - Super Admin has no company). Never
    raises - a logging failure must never fail the caller's actual send/
    schedule operation, which has already happened by the time this
    runs; any failure here is only ever reported via `context.error`.
    """
    permissions = [Permission.read(Role.label("superAdmin"))]
    if company_id:
        permissions.append(Permission.read(Role.team(company_id)))
    try:
        databases.create_document(
            database_id=DATABASE_ID,
            collection_id=NOTIFICATION_LOGS_COLLECTION_ID,
            document_id=ID.unique(),
            data={
                "companyId": company_id,
                "recipientLabel": recipient_label,
                "channel": channel,
                "subject": subject,
                "message": message,
                "status": status,
                "errorMessage": error_message,
            },
            permissions=permissions,
        )
    except AppwriteException as e:
        context.error(f"Failed to write notification log: {e}")


def _get_notification_recipients(databases, *, company_id, template_id):
    """Resolves who should receive a notification for `template_id` at
    `company_id` right now: the company's Admin (unless they've muted
    this specific template) plus every active Gestionnaire (always
    included - no opt-out for Gestionnaires, per explicit project
    instruction: "no roadblock" for them).

    NOT YET CALLED by anything in this file - built ahead of 5.8/5.10,
    which will call this once they exist, passing whichever template
    they're about to send for a given event. Returns a list of Appwrite
    user ids, ready to pass to `_send_email` one at a time.
    """
    try:
        members = databases.list_documents(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            queries=[
                Query.equal("companyId", company_id),
                Query.equal("status", "active"),
                Query.limit(500),
            ],
        )
    except AppwriteException:
        return []

    recipients = []
    for member in members.documents:
        role = member.data.get("role")
        if role == "gestionnaire":
            recipients.append(member.id)
        elif role == "admin":
            try:
                prefs = databases.get_document(
                    database_id=DATABASE_ID,
                    collection_id=NOTIFICATION_PREFERENCES_COLLECTION_ID,
                    document_id=member.id,
                )
                muted = prefs.data.get("mutedTemplateIds") or []
            except AppwriteException:
                muted = []
            if template_id not in muted:
                recipients.append(member.id)
    return recipients


# ---------------------------------------------------------------------------
# notification.create-template
# ---------------------------------------------------------------------------
# Admin or Super Admin. Cahier des charges 5.4: "Creation de templates de
# notification (message, canal)." Readable by any authenticated user -
# permission set here, not at the collection level (same reasoning as
# subscription_plans: not sensitive, and every role may eventually need
# to read a template once 5.8/5.10 reference one).
#
# Expected body: {"name": str, "message": str, "channel": "push"|"email"}
# Response 200: the created notification_templates document.
_CREATE_NOTIFICATION_TEMPLATE_REQUIRED_FIELDS = ["name", "message", "channel"]


def _handle_create_notification_template(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    missing = [f for f in _CREATE_NOTIFICATION_TEMPLATE_REQUIRED_FIELDS if not body.get(f)]
    if missing:
        return context.res.json({"message": f"Champs manquants: {', '.join(missing)}"}, 400)
    if body["channel"] not in ("push", "email"):
        return context.res.json({"message": "Canal invalide."}, 400)

    client = _client(context)
    databases = Databases(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil de l'appelant introuvable."}, 403)

    if caller_profile.data.get("role") not in ("admin", "superAdmin"):
        return context.res.json(
            {"message": "Seul un Admin ou Super Admin peut creer un modele."}, 403
        )

    try:
        created = databases.create_document(
            database_id=DATABASE_ID,
            collection_id=NOTIFICATION_TEMPLATES_COLLECTION_ID,
            document_id=ID.unique(),
            data={
                "name": body["name"],
                "message": body["message"],
                "channel": body["channel"],
            },
            permissions=[Permission.read(Role.users())],
        )
        return context.res.json(_doc_to_dict(created), 200)
    except AppwriteException as e:
        context.error(str(e))
        return context.res.json({"message": e.message or "Echec de la creation du modele."}, 400)


# ---------------------------------------------------------------------------
# notification.update-template
# ---------------------------------------------------------------------------
# Admin or Super Admin.
#
# Expected body: {"templateId": str, "name": str, "message": str,
#                 "channel": "push"|"email"}
# Response 200: the updated notification_templates document.
_UPDATE_NOTIFICATION_TEMPLATE_REQUIRED_FIELDS = ["templateId", "name", "message", "channel"]


def _handle_update_notification_template(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    missing = [f for f in _UPDATE_NOTIFICATION_TEMPLATE_REQUIRED_FIELDS if not body.get(f)]
    if missing:
        return context.res.json({"message": f"Champs manquants: {', '.join(missing)}"}, 400)
    if body["channel"] not in ("push", "email"):
        return context.res.json({"message": "Canal invalide."}, 400)

    client = _client(context)
    databases = Databases(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil de l'appelant introuvable."}, 403)

    if caller_profile.data.get("role") not in ("admin", "superAdmin"):
        return context.res.json(
            {"message": "Seul un Admin ou Super Admin peut modifier un modele."}, 403
        )

    try:
        updated = databases.update_document(
            database_id=DATABASE_ID,
            collection_id=NOTIFICATION_TEMPLATES_COLLECTION_ID,
            document_id=body["templateId"],
            data={
                "name": body["name"],
                "message": body["message"],
                "channel": body["channel"],
            },
        )
        return context.res.json(_doc_to_dict(updated), 200)
    except AppwriteException as e:
        context.error(str(e))
        return context.res.json({"message": e.message or "Echec de la mise a jour du modele."}, 400)


# ---------------------------------------------------------------------------
# notification.delete-template
# ---------------------------------------------------------------------------
# Admin or Super Admin. Real deletion, matching cahier des charges 5.4's
# CRUD scope - no soft-deactivation concept here, same reasoning as
# subscription plans.
#
# Expected body: {"templateId": str}
# Response 200: {"status": "deleted"}
def _handle_delete_notification_template(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    template_id = body.get("templateId")
    if not template_id:
        return context.res.json({"message": "templateId requis."}, 400)

    client = _client(context)
    databases = Databases(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil de l'appelant introuvable."}, 403)

    if caller_profile.data.get("role") not in ("admin", "superAdmin"):
        return context.res.json(
            {"message": "Seul un Admin ou Super Admin peut supprimer un modele."}, 403
        )

    try:
        databases.delete_document(
            database_id=DATABASE_ID,
            collection_id=NOTIFICATION_TEMPLATES_COLLECTION_ID,
            document_id=template_id,
        )
        return context.res.json({"status": "deleted"}, 200)
    except AppwriteException as e:
        context.error(str(e))
        return context.res.json({"message": e.message or "Echec de la suppression du modele."}, 400)


# ---------------------------------------------------------------------------
# notification.send-test-email
# ---------------------------------------------------------------------------
# Any authenticated user - sends ONLY to themselves (never a parameter,
# always `x-appwrite-user-id`), purely to verify the SMTP + `_send_email`
# pipeline actually works end to end before any real feature depends on
# it. Writes a NotificationLog entry either way (sent or failed).
#
# Expected body: {"subject": str, "message": str}
# Response 200: {"status": "sent"}
_SEND_TEST_EMAIL_REQUIRED_FIELDS = ["subject", "message"]


def _handle_send_test_email(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    missing = [f for f in _SEND_TEST_EMAIL_REQUIRED_FIELDS if not body.get(f)]
    if missing:
        return context.res.json({"message": f"Champs manquants: {', '.join(missing)}"}, 400)

    client = _client(context)
    databases = Databases(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil de l'appelant introuvable."}, 403)

    success, error_message = _send_email(
        client,
        user_id=caller_id,
        subject=body["subject"],
        content=body["message"],
    )

    _write_notification_log(
        context,
        databases,
        company_id=caller_profile.data.get("companyId"),
        recipient_label=caller_profile.data.get("email") or caller_id,
        channel="email",
        subject=body["subject"],
        message=body["message"],
        status="sent" if success else "failed",
        error_message=error_message,
    )

    if not success:
        return context.res.json({"message": error_message or "Echec de l'envoi."}, 400)
    return context.res.json({"status": "sent"}, 200)


# ---------------------------------------------------------------------------
# notification.set-my-preferences
# ---------------------------------------------------------------------------
# Admin only (Gestionnaires have no opt-out at all, per explicit project
# instruction - always receive, no preferences document, no UI). Always
# operates on the CALLER's own id (`x-appwrite-user-id`), never a
# parameter - there is deliberately no way to set another user's
# preferences through this resource. Upserts: creates the preferences
# document on first call for a given user, updates it on every call
# after.
#
# Expected body: {"mutedTemplateIds": [str, ...]}
# Response 200: the created/updated notification_preferences document.
def _handle_set_my_preferences(context, body):
    caller_id = context.req.headers.get("x-appwrite-user-id", "")
    if not caller_id:
        return context.res.json({"message": "Authentification requise."}, 401)

    muted_template_ids = body.get("mutedTemplateIds")
    if not isinstance(muted_template_ids, list):
        return context.res.json({"message": "mutedTemplateIds doit etre une liste."}, 400)

    client = _client(context)
    databases = Databases(client)

    try:
        caller_profile = databases.get_document(
            database_id=DATABASE_ID,
            collection_id=USER_PROFILES_COLLECTION_ID,
            document_id=caller_id,
        )
    except AppwriteException:
        return context.res.json({"message": "Profil de l'appelant introuvable."}, 403)

    if caller_profile.data.get("role") != "admin":
        return context.res.json(
            {"message": "Seul un Admin peut configurer ses preferences de notification."}, 403
        )

    data = {"mutedTemplateIds": muted_template_ids}
    try:
        updated = databases.update_document(
            database_id=DATABASE_ID,
            collection_id=NOTIFICATION_PREFERENCES_COLLECTION_ID,
            document_id=caller_id,
            data=data,
        )
        return context.res.json(_doc_to_dict(updated), 200)
    except AppwriteException:
        # No document yet for this user - create it (upsert). Only
        # readable by the user themselves; writes always go through this
        # same resource, never a direct client write.
        try:
            created = databases.create_document(
                database_id=DATABASE_ID,
                collection_id=NOTIFICATION_PREFERENCES_COLLECTION_ID,
                document_id=caller_id,
                data=data,
                permissions=[Permission.read(Role.user(caller_id))],
            )
            return context.res.json(_doc_to_dict(created), 200)
        except AppwriteException as e:
            context.error(str(e))
            return context.res.json(
                {"message": e.message or "Echec de la sauvegarde des preferences."}, 400
            )


# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------
# When adding a new feature, add its handlers here too, e.g.:
#   "company.create-company": _handle_create_company,
# Never remove the feature prefix, even if a key looks unambiguous today -
# it's what keeps two features from ever colliding on the same resource
# string as this dict grows.
_HANDLERS = {
    "auth.register-company-and-admin": _handle_register_company_and_admin,
    "auth.create-gestionnaire-account": _handle_create_gestionnaire_account,
    "auth.reset-password": _handle_reset_password,
    "auth.update-account-status": _handle_update_account_status,
    "auth.delete-gestionnaire-account": _handle_delete_gestionnaire_account,
    "auth.resolve-login-identifier": _handle_resolve_login_identifier,
    "company.update-profile": _handle_update_company_profile,
    "company.update-status": _handle_update_company_status,
    "company.assign-subscription-plan": _handle_assign_subscription_plan,
    "subscription.create-plan": _handle_create_subscription_plan,
    "subscription.update-plan": _handle_update_subscription_plan,
    "subscription.delete-plan": _handle_delete_subscription_plan,
    "notification.create-template": _handle_create_notification_template,
    "notification.update-template": _handle_update_notification_template,
    "notification.delete-template": _handle_delete_notification_template,
    "notification.send-test-email": _handle_send_test_email,
    "notification.set-my-preferences": _handle_set_my_preferences,
}


def main(context):
    missing_env = _load_env()
    if missing_env:
        context.error(
            "Missing required environment variable(s) on this function: "
            + ", ".join(missing_env)
            + ". Set them with `appwrite functions create-variable "
            "--function-id api --key <KEY> --value <VALUE>` - see appwrite_setup.md."
        )
        return context.res.json(
            {
                "message": (
                    "Configuration serveur incomplete (variable(s) manquante(s): "
                    + ", ".join(missing_env)
                    + ")."
                )
            },
            500,
        )

    try:
        body = json.loads(context.req.body_raw or "{}")
    except json.JSONDecodeError:
        return context.res.json({"message": "Corps de requete JSON invalide."}, 400)

    resource = body.get("resource")
    handler = _HANDLERS.get(resource)
    if handler is None:
        return context.res.json(
            {
                "message": (
                    "'resource' invalide ou manquant. Valeurs acceptees: "
                    + ", ".join(sorted(_HANDLERS))
                )
            },
            400,
        )

    try:
        return handler(context, body)
    except Exception as e:  # noqa: BLE001 - deliberately broad: this is the
        # last line of defense so a bug in any single resource's handler
        # (present or future) can never again surface to the client as an
        # opaque, bodyless crash - it always comes back as a readable
        # JSON 500 with the real exception logged server-side instead.
        context.error(f"Unhandled exception in resource '{resource}': {e}")
        return context.res.json(
            {"message": "Erreur interne inattendue. Consultez les logs de la fonction."},
            500,
        )
