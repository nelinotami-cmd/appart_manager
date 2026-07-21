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
every resource's individual needs so far): databases.read,
databases.write, users.write, teams.write. See appwrite_setup.md.
"""

import json
import os
import secrets

from appwrite.client import Client
from appwrite.services.databases import Databases
from appwrite.services.users import Users
from appwrite.services.teams import Teams
from appwrite.id import ID
from appwrite.permission import Permission
from appwrite.role import Role
from appwrite.query import Query
from appwrite.exception import AppwriteException

DATABASE_ID = os.environ["APPWRITE_DATABASE_ID"]
COMPANIES_COLLECTION_ID = os.environ["APPWRITE_COLLECTION_COMPANIES"]
USER_PROFILES_COLLECTION_ID = os.environ["APPWRITE_COLLECTION_USER_PROFILES"]


def _client(context):
    return (
        Client()
        .set_endpoint(os.environ["APPWRITE_FUNCTION_API_ENDPOINT"])
        .set_project(os.environ["APPWRITE_FUNCTION_PROJECT_ID"])
        .set_key(context.req.headers.get("x-appwrite-key", ""))
    )


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

        databases.create_document(
            database_id=DATABASE_ID,
            collection_id=COMPANIES_COLLECTION_ID,
            document_id=company_id,
            data={
                "name": body["companyName"],
                "contactEmail": body["companyContactEmail"],
                "contactPhone": body["companyContactPhone"],
                "address": body["companyAddress"],
                "status": "active",
                "subscriptionPlanId": None,
            },
        )

        # One Team per tenant company, sharing the company's document id.
        teams.create(team_id=company_id, name=body["companyName"])
        team_created = True

        user = users.create(
            user_id=ID.unique(),
            email=body["adminEmail"],
            phone=body["adminPhone"],
            password=body["password"],
            name=body["adminFullName"],
        )
        user_id = user["$id"]

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
                Permission.update(Role.team(company_id, "admin")),
                Permission.update(Role.user(user_id)),
            ],
        )

        return context.res.json(profile, 200)

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

    if caller_profile.get("role") != "admin" or caller_profile.get("status") != "active":
        return context.res.json(
            {"message": "Seul un Admin actif peut creer un compte Gestionnaire."}, 403
        )

    company_id = caller_profile.get("companyId")
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
        user_id = user["$id"]

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
                Permission.update(Role.team(company_id, "admin")),
                Permission.update(Role.user(user_id)),
            ],
        )
        profile["tempPassword"] = temp_password
        return context.res.json(profile, 200)

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

    is_super_admin = caller_profile.get("role") == "superAdmin"
    is_owning_admin = (
        caller_profile.get("role") == "admin"
        and caller_profile.get("companyId") == target_profile.get("companyId")
        and target_profile.get("role") == "gestionnaire"
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
        return context.res.json(updated, 200)
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

    is_super_admin = caller_profile.get("role") == "superAdmin"
    is_owning_admin = (
        caller_profile.get("role") == "admin"
        and caller_profile.get("companyId") == target_profile.get("companyId")
    )
    if not (is_super_admin or is_owning_admin) or target_profile.get("role") != "gestionnaire":
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

    if not result["documents"]:
        return context.res.json({"message": "Aucun compte associe a cet identifiant."}, 404)

    doc = result["documents"][0]
    return context.res.json({"userId": doc["$id"], "email": doc["email"]}, 200)


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
}


def main(context):
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

    return handler(context, body)
