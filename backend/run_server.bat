@echo off
REM ============================================================
REM  Demarrage du backend FinTrack (phase de test)
REM  Double-clique ce fichier, ou lance-le depuis un terminal.
REM ============================================================
cd /d %~dp0

REM 1) Cree l'environnement virtuel au premier lancement
if not exist venv (
  echo [1/3] Creation de l'environnement virtuel Python...
  python -m venv venv
)

call venv\Scripts\activate.bat

REM 2) Installe / met a jour les dependances
echo [2/3] Installation des dependances...
pip install -r requirements.txt >nul

REM 3) Applique les migrations de base de donnees
echo [3/3] Application des migrations...
python manage.py migrate

echo.
echo ============================================================
echo  Backend FinTrack demarre sur le port 8001
echo.
echo  - Dans un AUTRE terminal, lance :   ngrok http 8001
echo  - Copie l'URL https affichee par ngrok
echo  - Dans l'app : Parametres ^> Cloud ^> URL du serveur ^> colle l'URL
echo.
echo  Admin (pour rendre un compte premium) : http://127.0.0.1:8001/admin
echo  (cree ton compte admin une fois avec :  python manage.py createsuperuser)
echo.
echo  Laisse cette fenetre ouverte tant que tu testes. Ctrl+C pour arreter.
echo ============================================================
echo.
python manage.py runserver 0.0.0.0:8001
