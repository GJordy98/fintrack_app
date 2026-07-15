# FinTrack — Guide de la phase de test

Ce dossier `backend/` est à copier sur le **PC serveur** (celui qui reste allumé).
Les testeurs, eux, installent seulement l'**APK** sur leur téléphone Android.

---

## A. Sur le PC serveur (une seule fois)

Pré-requis : **Python 3.12** installé, et **ngrok** installé (https://ngrok.com).

1. Copier tout le dossier `backend/` sur ce PC (⚠️ inutile de copier le sous-dossier
   `venv` : il sera recréé automatiquement).
2. Ouvrir un terminal dans le dossier et créer le compte administrateur :
   ```
   python -m venv venv
   venv\Scripts\activate
   pip install -r requirements.txt
   python manage.py migrate
   python manage.py createsuperuser
   ```
   (choisis un identifiant + mot de passe que tu retiendras)

## B. À chaque session de test

1. **Démarrer le serveur** : double-clique **`run_server.bat`**
   (ou lance-le dans un terminal). Il installe/migre puis démarre sur le port 8001.
2. **Démarrer ngrok** dans un autre terminal :
   ```
   ngrok http 8001
   ```
   ngrok affiche une URL du type `https://xxxx-xx-xx.ngrok-free.app`.
   ⚠️ Cette URL **change à chaque redémarrage de ngrok** (offre gratuite).
3. **Communiquer l'URL aux testeurs** : chacun la colle dans l'app,
   **Paramètres → Cloud → URL du serveur**.

## C. Rendre un compte « premium » (payant) pour un testeur

1. Le testeur se connecte une fois dans l'app : **Paramètres → Cloud →
   « Se connecter pour sauvegarder »** (e-mail ou Google). Cela crée son compte
   côté serveur.
2. Toi, ouvre l'admin : `http://127.0.0.1:8001/admin` → connecte-toi.
3. Section **Profiles** → ouvre le compte du testeur → coche **`is_premium`** → Enregistrer.
   (option : `premium_until` = date d'expiration pour un accès temporaire)
4. Le testeur met l'app en arrière-plan puis la rouvre → il passe **Premium**.

Pour retirer le premium : décocher `is_premium`.

---

## Notes
- En phase de test, le serveur tourne en mode `DEBUG` : les jetons Firebase ne
  sont pas vérifiés cryptographiquement (`FIREBASE_CREDENTIALS` non posé). C'est
  suffisant pour un test fermé, **pas pour la production**.
- L'app reste **100 % utilisable hors-ligne** sans serveur : le serveur ne sert
  qu'à la sauvegarde/synchro cloud et au déblocage premium des comptes de test.
