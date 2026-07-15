from django.urls import path

from . import views

urlpatterns = [
    path("health/", views.health, name="health"),
    path("me/", views.me, name="me"),
    path("sync/push/", views.sync_push, name="sync-push"),
    path("sync/pull/", views.sync_pull, name="sync-pull"),
    path("logs/", views.ingest_logs, name="ingest-logs"),
]
