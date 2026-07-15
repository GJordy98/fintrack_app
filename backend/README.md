# FinTrack — Backend Django

API de sauvegarde et synchronisation cloud pour l'app FinTrack (local-first).
Le serveur **stocke et synchronise** les données de chaque utilisateur ; il ne
recalcule rien (les calculs restent locaux côté app).

## Architecture
- **Django 5 + Django REST Framework**
- **Auth** : token **Firebase** (`Authorization: Bearer <ID_TOKEN>`), vérifié via
  `firebase-admin`. En dev, en-tête `X-Dev-User: <nom>` pour tester sans Firebase.
- **Stockage** : SQLite en dev, **PostgreSQL** en prod (`DATABASE_URL`).
- **Synchro** : modèle générique `SyncRecord` (une entité = un JSON, keyé par
  utilisateur + type + id), résolution *last-write-wins*.

## Endpoints
| Méthode | URL | Rôle |
|--------|-----|------|
| GET | `/api/health/` | Contrôle de santé |
| GET | `/api/me/` | Infos de l'utilisateur connecté |
| POST | `/api/sync/push/` | Envoie les entités modifiées localement |
| GET | `/api/sync/pull/?since=<iso>` | Récupère les changements serveur |

### Format push
```json
{ "records": [
  { "entity_type": "account", "entity_id": "uuid",
    "payload": { ... }, "client_updated_at": "2026-07-14T10:00:00Z",
    "deleted": false }
] }
```

## Démarrage local
```bash
cd backend
python -m venv venv
venv\Scripts\activate           # Windows (ou: source venv/bin/activate)
pip install -r requirements.txt
copy .env.example .env          # puis adapte au besoin
python manage.py migrate
python manage.py runserver 127.0.0.1:8001
```
> Le port **8001** est utilisé pour ne pas entrer en conflit avec ClariDoc (8000).
> Depuis l'émulateur Android, l'hôte est accessible via `http://10.0.2.2:8001`.

## Passer en production (Firebase + PostgreSQL)
1. Console Firebase → Paramètres du projet → **Comptes de service** →
   *Générer une nouvelle clé privée* → dépose le fichier JSON dans `backend/`
   (ex : `firebase-service-account.json`).
2. Dans `.env` (ou variables d'environnement de l'hébergeur) :
   - `FIREBASE_CREDENTIALS=firebase-service-account.json`
   - `DEBUG=0`
   - `DATABASE_URL=postgres://...`
   - `SECRET_KEY=<clé forte>`
   - `ALLOWED_HOSTS=ton-domaine`
3. Déploiement Render/Railway : le `Procfile` lance `gunicorn` + `migrate`.

## Créer un admin (pour l'interface /admin)
```bash
python manage.py createsuperuser
```
