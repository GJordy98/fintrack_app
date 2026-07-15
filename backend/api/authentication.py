"""Authentification par token Firebase pour l'API FinTrack.

En production, chaque requête doit porter un en-tête
``Authorization: Bearer <ID_TOKEN_FIREBASE>``. Le token est vérifié via le SDK
firebase-admin, et un utilisateur Django est créé/associé à l'UID Firebase.

En développement (DEBUG et sans clé Firebase configurée), un en-tête
``X-Dev-User: <identifiant>`` suffit pour simuler un utilisateur — pratique pour
tester l'API sans Firebase.
"""

import base64
import json

from django.conf import settings
from django.contrib.auth import get_user_model
from rest_framework import authentication, exceptions

User = get_user_model()

_firebase_ready = False


def _decode_unverified(token):
    """Décode le payload d'un JWT SANS vérifier la signature.

    Réservé au développement local (voir usage plus bas) : permet de tester la
    synchronisation avec un vrai token Firebase sans configurer la clé de compte
    de service côté serveur. NE JAMAIS utiliser en production.
    """
    try:
        payload_b64 = token.split(".")[1]
        payload_b64 += "=" * (-len(payload_b64) % 4)  # padding base64
        return json.loads(base64.urlsafe_b64decode(payload_b64))
    except Exception as exc:
        raise exceptions.AuthenticationFailed(f"Token illisible : {exc}")


def _init_firebase():
    global _firebase_ready
    if _firebase_ready:
        return True
    if not settings.FIREBASE_CREDENTIALS:
        return False
    import firebase_admin
    from firebase_admin import credentials

    if not firebase_admin._apps:
        cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS)
        firebase_admin.initialize_app(cred)
    _firebase_ready = True
    return True


def _user_for(uid, email=None):
    user, _ = User.objects.get_or_create(
        username=uid,
        defaults={"email": email or ""},
    )
    if email and user.email != email:
        user.email = email
        user.save(update_fields=["email"])
    return user


class FirebaseAuthentication(authentication.BaseAuthentication):
    def authenticate(self, request):
        # --- Mode développement (aucune clé Firebase) ---
        if settings.DEBUG and not settings.FIREBASE_CREDENTIALS:
            dev = request.headers.get("X-Dev-User")
            if dev:
                return (_user_for(f"dev_{dev}", f"{dev}@dev.local"), None)

        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return None  # pas de credentials -> 401 via IsAuthenticated

        token = header.split(" ", 1)[1].strip()

        if not _init_firebase():
            # Dev local sans clé Firebase : on lit l'UID/e-mail depuis le token
            # SANS vérifier sa signature. INSECURE — uniquement quand DEBUG=True.
            # En production (DEBUG=False ou clé présente), la vérification
            # cryptographique ci-dessous est obligatoire.
            if settings.DEBUG:
                claims = _decode_unverified(token)
                uid = (
                    claims.get("user_id")
                    or claims.get("sub")
                    or claims.get("uid")
                )
                if not uid:
                    raise exceptions.AuthenticationFailed("Token sans UID.")
                return (_user_for(uid, claims.get("email")), claims)
            raise exceptions.AuthenticationFailed(
                "Firebase non configuré côté serveur."
            )

        from firebase_admin import auth as firebase_auth

        try:
            decoded = firebase_auth.verify_id_token(token)
        except Exception as exc:  # token invalide/expiré
            raise exceptions.AuthenticationFailed(f"Token invalide : {exc}")

        uid = decoded.get("uid")
        email = decoded.get("email")
        if not uid:
            raise exceptions.AuthenticationFailed("Token sans UID.")
        return (_user_for(uid, email), decoded)
