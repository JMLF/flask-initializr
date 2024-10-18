#!/bin/bash

# =============================================================================
# Script de déploiement du service systemd pour Gunicorn
# =============================================================================
# Ce script crée un fichier de service systemd pour Gunicorn, remplace les
# chemins par le répertoire actuel d'exécution, recharge systemd et démarre
# le service.
#
# Utilisation :
#   sudo ./deploy_service.sh
#
# Assurez-vous que le script est exécuté depuis le répertoire racine de
# votre projet Flask.
# =============================================================================

# Activer le mode strict
set -euo pipefail

# Fonction d'affichage de l'utilisation
usage() {
    echo "Usage: sudo $0"
    echo "Assurez-vous d'exécuter ce script depuis le répertoire racine de votre projet Flask."
    exit 1
}

# Vérifier si le script est exécuté avec des privilèges root
if [[ "$EUID" -ne 0 ]]; then
    echo "Ce script doit être exécuté avec des privilèges root. Utilisez sudo."
    usage
fi

if [[ -z "${SUDO_USER:-}" ]]; then
    echo "Impossible de déterminer l'utilisateur qui a exécuté le script."
    exit 1
fi

USER="$SUDO_USER"
GROUP=$(id -gn "$USER")  # Récupérer le groupe de l'utilisateur original

# Définir les variables par défaut
SERVICE_NAME="gunicorn_server.service"
PORT=8000 #TODO default + config
WORKERS=6 #TODO default + config
MODULE_APP="web:flask_web" 

echo " debug $USER et $GROUP"
exit 1

# Obtenir le répertoire actuel d'exécution
APP_DIR="$(pwd)"

# Vérifier que le répertoire existe
if [[ ! -d "$APP_DIR" ]]; then
    echo "Le répertoire $APP_DIR n'existe pas."
    exit 1
fi

# Trouver le chemin de l'environnement virtuel Poetry
# VENV_PATH=$(sudo -i -u "$USER" poetry env info --path 2>/dev/null || true)
POETRY_BIN="/home/$USER/.local/bin/poetry"
VENV_PATH=$(sudo -u "$USER" "$POETRY_BIN" env info --path 2>/dev/null || true)

if [[ -z "$VENV_PATH" ]]; then
    echo "Impossible de trouver l'environnement virtuel Poetry pour l'utilisateur $USER."
    echo "Assurez-vous que Poetry est installé et que vous avez configuré un environnement virtuel pour ce projet."
    exit 1
fi

# Définir le chemin vers Gunicorn
GUNICORN_PATH="$VENV_PATH/bin/gunicorn"

# Vérifier que Gunicorn est installé
if [[ ! -x "$GUNICORN_PATH" ]]; then
    echo "Gunicorn n'a pas été trouvé à l'emplacement $GUNICORN_PATH."
    echo "Assurez-vous que Gunicorn est installé dans votre environnement virtuel Poetry."
    exit 1
fi

# Définir le répertoire des logs
LOG_DIR="$APP_DIR/_logs"

# Créer le répertoire des logs s'il n'existe pas
sudo -u "$USER" mkdir -p "$LOG_DIR"

# Définir les chemins des fichiers de logs
ACCESS_LOG="$LOG_DIR/access.log"
ERROR_LOG="$LOG_DIR/error.log"

# Créer le contenu du fichier de service systemd
SERVICE_CONTENT="[Unit]
Description=Gunicorn server instance for $(basename "$APP_DIR")
After=network.target

[Service]
User=$USER
Group=$GROUP
WorkingDirectory=$APP_DIR
Environment=\"HOME=/home/$USER\"
Environment=\"PATH=$VENV_PATH/bin\"
ExecStart=$GUNICORN_PATH $MODULE_APP \
    --workers $WORKERS \
    --bind 0.0.0.0:$PORT \
    --access-logfile $ACCESS_LOG \
    --error-logfile $ERROR_LOG

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
"

# Définir le chemin du fichier de service systemd
SYSTEMD_PATH="/etc/systemd/system/$SERVICE_NAME"

# Créer un fichier temporaire pour le service
TEMP_SERVICE_FILE="/tmp/$SERVICE_NAME"

# Écrire le contenu du service dans le fichier temporaire
echo "$SERVICE_CONTENT" > "$TEMP_SERVICE_FILE"

# Définir les permissions appropriées
chmod 644 "$TEMP_SERVICE_FILE"

# Copier le fichier de service dans le répertoire systemd
cp "$TEMP_SERVICE_FILE" "$SYSTEMD_PATH"

# Nettoyer le fichier temporaire
rm "$TEMP_SERVICE_FILE"

# Recharger systemd pour prendre en compte le nouveau service
systemctl daemon-reload

# Activer le service pour qu'il démarre au boot
systemctl enable "$SERVICE_NAME"

# Démarrer le service
systemctl start "$SERVICE_NAME"

# Vérifier le statut du service
echo "Vérification du statut du service $SERVICE_NAME :"
systemctl status "$SERVICE_NAME" --no-pager

echo "Le service $SERVICE_NAME a été installé et démarré avec succès."
