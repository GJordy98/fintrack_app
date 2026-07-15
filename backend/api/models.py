from django.conf import settings
from django.db import models
from django.db.models.signals import post_save
from django.dispatch import receiver


class Profile(models.Model):
    """Profil applicatif lié à un utilisateur (1-1).

    Sert pour l'instant à accorder l'accès premium à un compte, y compris à des
    comptes de TEST : l'admin coche `is_premium` dans /admin et ce compte a
    accès à tout, sans passer par un achat Google Play. Le champ est renvoyé
    par `/api/me/` et lu par l'app.
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="profile",
    )
    is_premium = models.BooleanField(
        default=False,
        help_text="Débloque toutes les fonctionnalités premium pour ce compte "
        "(utile pour les comptes de test).",
    )
    # Optionnel : date d'expiration d'un accès premium accordé manuellement.
    premium_until = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        flag = "premium" if self.is_premium else "gratuit"
        return f"{self.user.username} ({flag})"


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def _ensure_profile(sender, instance, created, **kwargs):
    """Crée automatiquement un Profile à la création d'un utilisateur."""
    if created:
        Profile.objects.get_or_create(user=instance)


class SyncRecord(models.Model):
    """Copie serveur d'une entité de l'app (compte, transaction, objectif...).

    Le serveur ne recalcule rien : il stocke le JSON de l'entité tel que l'app
    l'envoie, pour la sauvegarde et la synchronisation multi-appareil. La clé
    logique est (utilisateur, type d'entité, id de l'entité).
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="sync_records",
    )
    entity_type = models.CharField(max_length=64)
    entity_id = models.CharField(max_length=64)
    payload = models.JSONField(default=dict, blank=True)

    # Horodatage côté client (updatedAt de l'entité) : sert au « last-write-wins ».
    client_updated_at = models.DateTimeField()
    # Horodatage serveur : sert au « pull depuis ».
    server_updated_at = models.DateTimeField(auto_now=True)

    deleted = models.BooleanField(default=False)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "entity_type", "entity_id"],
                name="unique_entity_per_user",
            )
        ]
        indexes = [
            models.Index(fields=["user", "server_updated_at"]),
        ]

    def __str__(self):
        return f"{self.entity_type}:{self.entity_id} ({self.user_id})"


class ErrorLog(models.Model):
    """Erreur ou avertissement remonté par l'application mobile.

    Destiné UNIQUEMENT à l'administration : les logs ne sont jamais affichés
    dans l'app côté utilisateur. Ils sont envoyés silencieusement par le
    client et consultables ici via le dashboard admin Django (/admin).
    L'utilisateur est facultatif (l'app est utilisable sans connexion).
    """

    LEVELS = (
        ("info", "Info"),
        ("warning", "Avertissement"),
        ("error", "Erreur"),
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="error_logs",
    )
    level = models.CharField(max_length=16, choices=LEVELS, default="error")
    message = models.TextField()
    stacktrace = models.TextField(blank=True, default="")

    # Contexte de l'appareil (pour reproduire / cibler un correctif).
    platform = models.CharField(max_length=32, blank=True, default="")
    app_version = models.CharField(max_length=32, blank=True, default="")
    device_model = models.CharField(max_length=128, blank=True, default="")
    os_version = models.CharField(max_length=64, blank=True, default="")

    # Horodatage côté appareil (quand l'erreur s'est produite) + réception serveur.
    client_time = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["level", "created_at"]),
        ]

    def __str__(self):
        head = self.message[:60].replace("\n", " ")
        return f"[{self.level}] {head}"
