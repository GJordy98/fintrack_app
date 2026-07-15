from datetime import timezone as dt_timezone

from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response

from .models import ErrorLog, Profile, SyncRecord


def _is_premium(user):
    """Vrai si le compte a l'accès premium accordé côté serveur (admin)."""
    profile = Profile.objects.filter(user=user).first()
    if profile is None or not profile.is_premium:
        return False
    if profile.premium_until is not None and profile.premium_until < timezone.now():
        return False
    return True


def _parse_dt(value):
    if not value:
        return None
    dt = parse_datetime(value)
    if dt is None:
        return None
    if timezone.is_naive(dt):
        dt = timezone.make_aware(dt, dt_timezone.utc)
    return dt


@api_view(["GET"])
@permission_classes([AllowAny])
def health(request):
    return Response({"status": "ok", "service": "fintrack-backend"})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def me(request):
    u = request.user
    return Response({
        "uid": u.username,
        "email": u.email,
        "is_premium": _is_premium(u),
    })


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def sync_push(request):
    """Reçoit les entités modifiées localement et les enregistre.

    Corps attendu : { "records": [ {entity_type, entity_id, payload,
    client_updated_at, deleted}, ... ] }. Résolution de conflit :
    last-write-wins sur ``client_updated_at``.
    """
    records = request.data.get("records", [])
    if not isinstance(records, list):
        return Response(
            {"detail": "'records' doit être une liste."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    applied = 0
    skipped = 0
    for r in records:
        entity_type = r.get("entity_type")
        entity_id = r.get("entity_id")
        client_dt = _parse_dt(r.get("client_updated_at"))
        if not entity_type or not entity_id or client_dt is None:
            skipped += 1
            continue

        existing = SyncRecord.objects.filter(
            user=request.user, entity_type=entity_type, entity_id=entity_id
        ).first()

        # Last-write-wins : on ignore une version plus ancienne que la stockée.
        if existing and existing.client_updated_at > client_dt:
            skipped += 1
            continue

        SyncRecord.objects.update_or_create(
            user=request.user,
            entity_type=entity_type,
            entity_id=entity_id,
            defaults={
                "payload": r.get("payload", {}),
                "client_updated_at": client_dt,
                "deleted": bool(r.get("deleted", False)),
            },
        )
        applied += 1

    return Response(
        {
            "server_time": timezone.now().isoformat(),
            "applied": applied,
            "skipped": skipped,
        }
    )


_VALID_LEVELS = {c[0] for c in ErrorLog.LEVELS}
_MAX_LOGS_PER_REQUEST = 200


@api_view(["POST"])
@permission_classes([AllowAny])
def ingest_logs(request):
    """Reçoit les erreurs/avertissements de l'app (destinés à l'admin).

    L'app est utilisable sans connexion : l'utilisateur est facultatif. On
    associe l'utilisateur seulement s'il est authentifié. Corps attendu :
    { "logs": [ {level, message, stacktrace, platform, app_version,
    device_model, os_version, client_time}, ... ] }.
    """
    logs = request.data.get("logs", [])
    if not isinstance(logs, list):
        return Response(
            {"detail": "'logs' doit être une liste."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user = request.user if request.user.is_authenticated else None
    created = 0
    for item in logs[:_MAX_LOGS_PER_REQUEST]:
        if not isinstance(item, dict):
            continue
        message = (item.get("message") or "").strip()
        if not message:
            continue
        level = item.get("level")
        if level not in _VALID_LEVELS:
            level = "error"
        ErrorLog.objects.create(
            user=user,
            level=level,
            message=message[:20000],
            stacktrace=(item.get("stacktrace") or "")[:40000],
            platform=(item.get("platform") or "")[:32],
            app_version=(item.get("app_version") or "")[:32],
            device_model=(item.get("device_model") or "")[:128],
            os_version=(item.get("os_version") or "")[:64],
            client_time=_parse_dt(item.get("client_time")),
        )
        created += 1

    return Response(
        {"created": created}, status=status.HTTP_201_CREATED
    )


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def sync_pull(request):
    """Renvoie les entités modifiées côté serveur depuis ``since`` (ISO 8601).

    Sans ``since``, renvoie tout (première synchro / restauration).
    """
    since = _parse_dt(request.query_params.get("since"))
    qs = SyncRecord.objects.filter(user=request.user)
    if since is not None:
        qs = qs.filter(server_updated_at__gt=since)
    qs = qs.order_by("server_updated_at")

    records = [
        {
            "entity_type": rec.entity_type,
            "entity_id": rec.entity_id,
            "payload": rec.payload,
            "client_updated_at": rec.client_updated_at.isoformat(),
            "server_updated_at": rec.server_updated_at.isoformat(),
            "deleted": rec.deleted,
        }
        for rec in qs
    ]
    return Response(
        {"server_time": timezone.now().isoformat(), "records": records}
    )
