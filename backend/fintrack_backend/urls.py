"""Routes du backend FinTrack."""

from django.contrib import admin
from django.urls import include, path

from api import views

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include("api.urls")),
    # Racine : petit contrôle de santé.
    path("", views.health),
]
