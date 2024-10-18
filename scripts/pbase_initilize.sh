#!/bin/bash

# =============================================================================
# Script d'initialisation d'un projet Flask avec Poetry
# =============================================================================
# Ce script initialise un nouveau projet Flask avec Poetry, crée l'architecture
# de dossier adaptée pour un projet Flask de type API/Web et installe les
# dépendances de base.
#
# Utilisation :
#   ./initialize_flask_project.sh nom_du_projet
#
# =============================================================================

# Activer le mode strict
set -euo pipefail

# Vérifier si le nom du projet est fourni
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 nom_du_projet"
    exit 1
fi

# Récupérer le nom du projet depuis les arguments
PROJECT_NAME=$1

# Vérifier si Poetry est installé
if ! command -v poetry &> /dev/null; then
    echo "Poetry n'est pas installé. Installez-le d'abord : https://python-poetry.org/docs/#installation"
    exit 1
fi

# Créer un nouveau projet avec Poetry
echo "Création du projet $PROJECT_NAME avec Poetry..."
poetry new "$PROJECT_NAME" --src

# Naviguer dans le répertoire du projet
cd "$PROJECT_NAME"

# Installer Flask
echo "Installation de Flask avec Poetry..."
poetry add flask python-dotenv

# Créer l'architecture de dossiers
echo "Création de l'architecture de dossiers pour le projet Flask..."
mkdir -p src/$PROJECT_NAME/{api,static,templates,config}

# Créer un fichier app.py de base
APP_FILE="src/$PROJECT_NAME/app.py"
cat << EOF > "$APP_FILE"
from flask import Flask, jsonify
import os

def create_app():
    app = Flask(__name__)

    # Charger la configuration selon l'environnement FLASK_ENV
    config_type = os.getenv('FLASK_ENV', 'development')
    
    if config_type == 'production':
        app.config.from_object('$PROJECT_NAME.config.default.ProductionConfig')
    elif config_type == 'testing':
        app.config.from_object('$PROJECT_NAME.config.default.TestingConfig')
    else:
        app.config.from_object('$PROJECT_NAME.config.default.DevelopmentConfig')

    @app.route('/api/ping', methods=['GET'])
    def ping():
        return jsonify({'message': 'pong'})

    return app

if __name__ == "__main__":
    app = create_app()
    app.run(host='0.0.0.0', port=5000)
EOF

# Créer un fichier de configuration par défaut
CONFIG_FILE="src/$PROJECT_NAME/config/default.py"
cat << EOF > "$CONFIG_FILE"
import os

class Config:
    """Configuration de base, valable pour tous les environnements."""
    SECRET_KEY = os.getenv('SECRET_KEY', 'default_secret_key')  # Clé par défaut si non définie dans .env
    DEBUG = False
    TESTING = False
    #DATABASE_URI = os.getenv('DATABASE_URL', 'sqlite:///data.db')  # Base de données par défaut

class DevelopmentConfig(Config):
    """Configuration pour le développement."""
    DEBUG = True
    FLASK_ENV = 'development'

class ProductionConfig(Config):
    """Configuration pour la production."""
    FLASK_ENV = 'production'
    #DATABASE_URI = os.getenv('DATABASE_URL', 'postgresql://user@localhost/dbname')  # Remplacez par vos valeurs

class TestingConfig(Config):
    """Configuration pour les tests."""
    TESTING = True
    #DATABASE_URI = 'sqlite:///:memory:'  # Base de données en mémoire pour les tests
EOF

# Créer un fichier .env pour les variables d'environnement
ENV_FILE=".env"
cat << EOF > "$ENV_FILE"
# Variables d'environnement
SECRET_KEY=super_secret_key
FLASK_ENV=development
FLASK_APP=run.py
EOF

# Créer un fichier run.py pour faciliter l'exécution du projet
RUN_FILE="run.py"
cat << EOF > "$RUN_FILE"
from src.$PROJECT_NAME.app import create_app

app = create_app()

if __name__ == "__main__":
    app.run()
EOF

# Créer des dossiers pour les modèles, les routes et les tests (si besoin)
echo "Création des dossiers supplémentaires pour les routes, modèles et tests..."
mkdir -p src/$PROJECT_NAME/{models,routes}
mkdir -p tests

# Créer un fichier README
README_FILE="README.md"
cat << EOF > "$README_FILE"
# $PROJECT_NAME

## Installation

1. Installer [Poetry](https://python-poetry.org/).
2. Installer les dépendances du projet :

    \`\`\`bash
    poetry install
    \`\`\`

3. Configurer les variables d'environnement dans le fichier \`.env\`.
4. Lancer le serveur Flask en mode développement :

    \`\`\`bash
    poetry run python run.py
    \`\`\`

## Routes API

- \`GET /api/ping\` : Test de l'API, renvoie un message "pong".
EOF

# Initialiser git si besoin
# TODO ask user 
echo "Initialisation de git..."
git init
touch .gitignore
echo "env/\n__pycache__/\n*.pyc\n*.pyo\n*.pyd\nmigrations/" > .gitignore

echo "Le projet $PROJECT_NAME a été créé avec succès !"
echo "Structure de base créée, et Flask installé."
echo "Exécutez 'poetry install' pour installer les dépendances supplémentaires."
