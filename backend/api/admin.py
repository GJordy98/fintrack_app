from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .models import ErrorLog, Profile, SyncRecord


@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    list_display = ("user", "is_premium", "premium_until", "updated_at")
    list_filter = ("is_premium",)
    list_editable = ("is_premium",)  # coche/décoche directement dans la liste
    search_fields = ("user__username", "user__email")
    readonly_fields = ("created_at", "updated_at")


class ProfileInline(admin.StackedInline):
    model = Profile
    can_delete = False
    verbose_name_plural = "Profil (premium)"
    extra = 0


# Rend `is_premium` visible/éditable aussi depuis la fiche utilisateur.
User = get_user_model()
try:
    admin.site.unregister(User)
except admin.sites.NotRegistered:
    pass


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    inlines = (ProfileInline,)


@admin.register(SyncRecord)
class SyncRecordAdmin(admin.ModelAdmin):
    list_display = (
        "entity_type",
        "entity_id",
        "user",
        "deleted",
        "client_updated_at",
        "server_updated_at",
    )
    list_filter = ("entity_type", "deleted")
    search_fields = ("entity_id", "user__username")


@admin.register(ErrorLog)
class ErrorLogAdmin(admin.ModelAdmin):
    list_display = (
        "created_at",
        "level",
        "short_message",
        "user",
        "platform",
        "app_version",
        "device_model",
    )
    list_filter = ("level", "platform", "app_version")
    search_fields = ("message", "stacktrace", "user__username", "device_model")
    date_hierarchy = "created_at"
    readonly_fields = (
        "user",
        "level",
        "message",
        "stacktrace",
        "platform",
        "app_version",
        "device_model",
        "os_version",
        "client_time",
        "created_at",
    )

    @admin.display(description="Message")
    def short_message(self, obj):
        head = obj.message[:80].replace("\n", " ")
        return head + ("…" if len(obj.message) > 80 else "")

    def has_add_permission(self, request):
        # Les logs sont créés par l'app, jamais à la main dans l'admin.
        return False
