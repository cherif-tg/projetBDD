# Station-Service — Système de facturation (ProjetBDD)

Résumé
------
Petit système de facturation pour une station-service. Contient :
- Backend Flask : `ProjetBDD/StationService/app.py`
- Templates / UI : `ProjetBDD/StationService/templates/` (ex. `factures.html`)
- Script SQL pour la base : `ProjetBDD/station_service_db.sql`

Prérequis
---------
- Python 3.10+ (ou 3.8+)
- PostgreSQL
- Créer un environnement virtuel et installer dépendances (exemple) :

```bash
python -m venv .venv
source .venv/bin/activate   # Unix
.venv\Scripts\activate     # Windows PowerShell
pip install -r ProjetBDD/requirements.txt
```

Variables d'environnement
-------------------------
Créer un fichier `.env` dans `ProjetBDD/StationService/` contenant :

```
DB_HOST=localhost
DB_NAME=stationBDD
DB_USER=postgres
DB_PASSWORD=yourpassword
DB_PORT=5432
SECRET_KEY=changeme
```

Initialiser la base
-------------------
Importer le script SQL (exemple) :

```bash
psql -U postgres -d postgres -f "c:/Users/Ce PC/OneDrive - Le Gret/Bureau/Programation/ProjetBDD/station_service_db.sql"
# ou créer la BD puis l'utiliser : createdb stationBDD -U postgres
# psql -U postgres -d stationBDD -f ProjetBDD/station_service_db.sql
```

Lancer l'application (développement)
-----------------------------------

```bash
cd "c:/Users/Ce PC/OneDrive - Le Gret/Bureau/Programation/ProjetBDD/StationService"
set FLASK_APP=app.py        # Windows
flask run --host=0.0.0.0 --port=5000
# ou python app.py
```

Points importants et recommandations
-----------------------------------
- Noms de tables/colonnes : le fichier SQL contient des incohérences (singulier/pluriel, noms de colonnes) par rapport à `app.py`. Il faut standardiser : je recommande d'utiliser des noms pluriels cohérents (`clients`, `services`, `factures`, `lignes_factures`, `paiements`, `utilisateurs`).
- Séparer le code : extraire la configuration (`config.py`), routes (BluePrints), et la logique DB (DAO) pour rendre le projet maintenable.
- Ajouter `requirements.txt` et utiliser `psycopg2-binary`, `Flask`, `python-dotenv`, `reportlab`, `Flask-CORS`.
- Ajouter gestion des migrations (Flyway/psql scripts ou Alembic) et tests de sanity pour l'import SQL.
- API paths : préférer des routes préfixées `/api/...` et utiliser des réponses JSON cohérentes `{ "success": true, ... }`.
- Sécuriser : retirer `SECRET_KEY` en dur dans `app.py` et le placer dans `.env`.
- Frontend : déplacer CSS/JS dans `static/` et templates dans `templates/`, et corriger les appels `fetch` pour pointer sur `/api/...`.

Prochaine étape suggérée
-----------------------
- Choisir la stratégie : corriger le SQL pour correspondre à `app.py` ou modifier `app.py` pour matcher le SQL. Je peux appliquer les modifications si tu veux (ex : renommer les requêtes SQL dans `app.py` ou nettoyer le script SQL).

Contact
-------
Si tu veux que j'applique automatiquement les corrections (SQL ↔ backend), dis-moi quelle option tu préfères.

Requirements
------------
Installer les dépendances recommandées via :

```bash
cd "c:/Users/Ce PC/OneDrive - Le Gret/Bureau/Programation/ProjetBDD"
python -m venv .venv
.venv\Scripts\activate    # Windows PowerShell
pip install -r requirements.txt
```

Importer la base (exemple de commandes)
--------------------------------------
1) Créer la base PostgreSQL (si besoin) :

```bash
psql -U postgres -c "CREATE DATABASE stationBDD;"
```

2) Importer le schéma nettoyé :

```bash
psql -U postgres -d stationBDD -f "c:/Users/Ce PC/OneDrive - Le Gret/Bureau/Programation/ProjetBDD/station_service_db.sql"
```

Remarque: si `psql` n'est pas dans le PATH, utilisez l'interface PostgreSQL ou PgAdmin pour importer.

Changements appliqués
---------------------
- Le fichier `station_service_db.sql` a été nettoyé et standardisé pour correspondre aux routes et attentes de `ProjetBDD/StationService/app.py` (tables pluriel : `clients`, `services`, `factures`, `lignes_factures`, `paiements`, `utilisateur`).
- Ajout de `requirements.txt` pour installer les dépendances Python minimales.

