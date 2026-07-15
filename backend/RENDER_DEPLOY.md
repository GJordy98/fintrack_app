# Déployer le backend FinTrack sur Render

Render héberge le backend en ligne (URL **stable**, contrairement à ngrok) et
fournit une base **PostgreSQL** gratuite. Les testeurs n'ont besoin que de l'APK.

---

## 1. Mettre le projet sur GitHub

Le dépôt contient **tout le projet** (app Flutter + `backend/`). Le fichier
`render.yaml` est à la **racine** et indique à Render que le serveur est dans
`backend/` (via `rootDir`). Les `.gitignore` excluent déjà les secrets, le
`venv`, la base locale et les dossiers de build — rien de sensible n'est publié.

Le dépôt local est **déjà initialisé et committé**. Il ne reste qu'à pousser
(le push demande tes identifiants GitHub) :
```
git push -u origin main
```
Si le push est refusé parce que le dépôt distant a déjà un commit (README créé
sur GitHub), fais d'abord :
```
git pull --rebase origin main
git push -u origin main
```

## 2. Créer les services sur Render (Blueprint)

1. Va sur https://render.com → connecte-toi (via GitHub, c'est plus simple).
2. **New +** → **Blueprint**.
3. Sélectionne ton dépôt `fintrack-backend`. Render détecte `render.yaml`.
4. Avant de valider, il te demande les variables marquées « à saisir » :
   - **DJANGO_SUPERUSER_PASSWORD** : choisis le mot de passe de ton compte admin.
   - **FIREBASE_CREDENTIALS** : **laisse vide** (mode test).
5. Clique **Apply**. Render crée :
   - `fintrack-db` (PostgreSQL gratuit),
   - `fintrack-backend` (service web) qui installe, migre, crée l'admin et démarre.
6. Attends la fin du déploiement (statut **Live**). Ton URL s'affiche en haut,
   du type : **`https://fintrack-backend.onrender.com`**.

Vérifie que ça marche : ouvre `https://…onrender.com/api/health/` →
tu dois voir `{"status": "ok", ...}`.

## 3. Se connecter à l'admin

Ouvre `https://…onrender.com/admin` → connecte-toi avec :
- identifiant : **admin** (valeur par défaut, modifiable dans le dashboard),
- mot de passe : celui que tu as saisi à l'étape 2.

C'est ici que tu débloques un compte en premium : **Profiles** → coche
`is_premium` sur le compte du testeur.

## 4. Relier l'app à ce serveur

Deux options :

**A. Les testeurs collent l'URL** (rien à rebuild)
Chaque testeur : Paramètres → Cloud → **URL du serveur** → colle
`https://…onrender.com`.

**B. URL intégrée à l'APK** (aucune manip pour les testeurs) — *recommandé*
Une fois l'URL Render connue, je te régénère l'APK avec l'URL intégrée :
```
flutter build apk --release --no-tree-shake-icons \
  --dart-define=FINTRACK_API_URL=https://fintrack-backend.onrender.com
```
→ Donne-moi l'URL Render et je relance ce build pour toi.

---

## Points importants
- **Plan gratuit = mise en veille** : après 15 min sans requête, le serveur
  s'endort ; la 1re requête suivante prend ~50 s (le temps qu'il redémarre).
  Sans conséquence pour l'app (la synchro est non bloquante), mais le tout
  premier chargement après une pause est lent.
- **Base gratuite** : la Postgres gratuite de Render expire après ~90 jours
  (Render prévient par e-mail). Pour un usage durable, prévoir un plan payant.
- **Sécurité** : ce déploiement de test tourne en `DEBUG=1` (les tokens Firebase
  ne sont pas vérifiés cryptographiquement). Pour la **production**, dans le
  dashboard Render : mettre `DEBUG=0` **et** coller le JSON du compte de service
  Firebase dans `FIREBASE_CREDENTIALS`, puis redéployer.
- **Redéployer après une modif** : `git push` → Render redéploie tout seul.
