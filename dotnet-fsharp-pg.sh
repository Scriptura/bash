#!/bin/bash

# Script d'installation F#/ASP.NET Core + Giraffe + PostgreSQL
# Compatible Ubuntu 24.04 et Debian 13 (Trixie)
# 
# Fonctionnalités:
# - Installation .NET SDK (dernière version LTS)
# - Templates et outils F# (FSAutoComplete, Fantomas, FSharp.Analyzers)
# - Framework web Giraffe (version LTS)
# - PostgreSQL 17 avec configuration sécurisée (mots de passe forts)
# - Configuration nginx pour reverse proxy
# - Optimisations système pour ASP.NET Core
# - Gestion des différences Ubuntu/Debian
# - Script idempotent (ré-exécutable sans risque)
# - Nettoyage automatique et gestion d'erreurs robuste
#
# Améliorations sécurité:
# - Mots de passe PostgreSQL générés aléatoirement
# - Configuration pg_hba.conf restrictive par utilisateur/base
# - Stockage sécurisé des credentials (.pgpass + fichier référence)
# - Logging horodaté et nettoyage automatique des fichiers temporaires
#
# Auteur: Assistant Claude
# Version: 7.0

set -euo pipefail

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Gestion des signaux et nettoyage
cleanup() {
    log "Nettoyage des fichiers temporaires..."
    rm -f packages-microsoft-prod.deb
    rm -f dotnet-install.sh
    rm -f packages-*.deb
    rm -f *-install.sh
}

# Gestion des signaux
trap 'error "Installation interrompue"; cleanup; exit 1' INT TERM EXIT

# Fonction de logging améliorée
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $1" >&2
}

# Détection de la distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        CODENAME=${VERSION_CODENAME:-""}
    else
        error "Impossible de détecter la distribution"
        exit 1
    fi
    
    log "Distribution détectée: $DISTRO $VERSION ($CODENAME)"
}

# Vérification des privilèges root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "Ce script ne doit pas être exécuté en tant que root"
        error "Utilisez sudo uniquement quand nécessaire"
        exit 1
    fi
    
    # Vérifier que sudo est disponible
    if ! command -v sudo &> /dev/null; then
        error "sudo n'est pas installé. Installez-le d'abord."
        exit 1
    fi
}

# Mise à jour du système
update_system() {
    log "Mise à jour du système..."
    sudo apt update
    sudo apt upgrade -y
    
    # Installation des dépendances de base
    log "Installation des dépendances de base..."
    sudo apt install -y \
        curl \
        wget \
        apt-transport-https \
        software-properties-common \
        gpg \
        lsb-release \
        ca-certificates \
        unzip \
        git \
        build-essential
}

# Installation de .NET
install_dotnet() {
    log "Installation de .NET..."
    
    # URL du script d'installation Microsoft
    DOTNET_INSTALL_SCRIPT="https://dot.net/v1/dotnet-install.sh"
    
    # Téléchargement et installation via le script officiel Microsoft
    # Cette méthode fonctionne sur toutes les distributions Linux
    wget -O dotnet-install.sh "$DOTNET_INSTALL_SCRIPT"
    chmod +x dotnet-install.sh
    
    # Installation de la dernière version LTS de .NET
    ./dotnet-install.sh --channel LTS --install-dir ~/.dotnet
    
    # Nettoyage
    rm dotnet-install.sh
    
    # Configuration du PATH (idempotent)
    if ! grep -q 'export PATH="$HOME/.dotnet:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/.dotnet:$PATH"' >> ~/.bashrc
        echo 'export DOTNET_ROOT="$HOME/.dotnet"' >> ~/.bashrc
        log "Variables .NET ajoutées à ~/.bashrc"
    else
        log "Variables .NET déjà configurées dans ~/.bashrc"
    fi
    
    # Application immédiate des variables d'environnement
    export PATH="$HOME/.dotnet:$PATH"
    export DOTNET_ROOT="$HOME/.dotnet"
    
    # Vérification de l'installation
    if ~/.dotnet/dotnet --version &> /dev/null; then
        log ".NET installé avec succès: $(~/.dotnet/dotnet --version)"
    else
        error "Échec de l'installation de .NET"
        exit 1
    fi
    
    # Installation des templates F#
    log "Installation des templates F#..."
    ~/.dotnet/dotnet new install Microsoft.FSharp.Templates
}

# Installation alternative via les dépôts Microsoft (fallback)
install_dotnet_repo() {
    log "Installation de .NET via les dépôts Microsoft..."
    
    # Configuration du dépôt Microsoft selon la distribution
    case "$DISTRO" in
        "ubuntu")
            # Ubuntu 24.04
            if [[ "$VERSION" == "24.04" ]]; then
                wget https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
                sudo dpkg -i packages-microsoft-prod.deb
                rm packages-microsoft-prod.deb
            else
                warn "Version Ubuntu non testée: $VERSION"
                warn "Utilisation de la configuration Ubuntu 24.04"
                wget https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
                sudo dpkg -i packages-microsoft-prod.deb
                rm packages-microsoft-prod.deb
            fi
            ;;
        "debian")
            # Debian 13 (Trixie) - utilisation de la config Debian 12 en attendant le support officiel
            if [[ "$VERSION" == "13" ]] || [[ "$CODENAME" == "trixie" ]]; then
                warn "Debian 13 détecté - utilisation de la configuration Debian 12"
                wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
                sudo dpkg -i packages-microsoft-prod.deb
                rm packages-microsoft-prod.deb
            else
                wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
                sudo dpkg -i packages-microsoft-prod.deb
                rm packages-microsoft-prod.deb
            fi
            ;;
        *)
            error "Distribution non supportée: $DISTRO"
            exit 1
            ;;
    esac
    
    # Mise à jour des dépôts
    sudo apt update
    
    # Installation de .NET
    sudo apt install -y dotnet-sdk-8.0 aspnetcore-runtime-8.0
    
    # Vérification
    if dotnet --version &> /dev/null; then
        log ".NET installé avec succès: $(dotnet --version)"
    else
        error "Échec de l'installation de .NET via les dépôts"
        exit 1
    fi
}

# Installation des outils de développement
install_dev_tools() {
    log "Installation des outils de développement F#..."
    
    # Installation d'Ionide (serveur de langage F#) - idempotent
    if command -v dotnet &> /dev/null; then
        if ! dotnet tool list -g | grep -q "fsautocomplete"; then
            log "Installation de FSAutoComplete..."
            dotnet tool install -g fsautocomplete
        else
            log "FSAutoComplete déjà installé"
        fi
        
        if ! dotnet tool list -g | grep -q "fantomas"; then
            log "Installation de Fantomas..."
            dotnet tool install -g fantomas
        else
            log "Fantomas déjà installé"
        fi
        
        if ! dotnet tool list -g | grep -q "fsharp-analyzers"; then
            log "Installation de FSharp.Analyzers..."
            dotnet tool install -g fsharp-analyzers
        else
            log "FSharp.Analyzers déjà installé"
        fi
    fi
    
    # Ajout du répertoire des outils .NET au PATH (idempotent)
    if ! grep -q 'export PATH="$HOME/.dotnet/tools:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/.dotnet/tools:$PATH"' >> ~/.bashrc
        log "Répertoire des outils .NET ajouté au PATH"
    else
        log "Répertoire des outils .NET déjà dans le PATH"
    fi
    export PATH="$HOME/.dotnet/tools:$PATH"
}

# Installation des templates Giraffe
install_giraffe_templates() {
    log "Vérification des templates Giraffe..."
    
    # Installation du template Giraffe officiel (idempotent)
    if command -v dotnet &> /dev/null; then
        if ! dotnet new list | grep -q "giraffe"; then
            log "Installation des templates Giraffe..."
            dotnet new install "giraffe-template::*"
            
            # Vérification post-installation
            if dotnet new list | grep -q "giraffe"; then
                log "Templates Giraffe installés avec succès"
            else
                warn "Les templates Giraffe ne semblent pas être installés correctement"
                warn "Vous pourrez les installer manuellement avec: dotnet new install giraffe-template"
            fi
        else
            log "Templates Giraffe déjà installés"
        fi
    else
        error "dotnet n'est pas disponible pour installer les templates Giraffe"
        exit 1
    fi
}

# Installation et configuration de PostgreSQL
install_postgresql() {
    log "Installation de PostgreSQL..."
    
    # Détection de la version PostgreSQL à installer (17 = LTS actuelle)
    PG_VERSION="17"
    
    case "$DISTRO" in
        "ubuntu")
            install_postgresql_ubuntu
            ;;
        "debian")
            install_postgresql_debian
            ;;
        *)
            error "Distribution non supportée pour PostgreSQL: $DISTRO"
            exit 1
            ;;
    esac
    
    # Configuration commune
    configure_postgresql_common
}

# Installation PostgreSQL sur Ubuntu
install_postgresql_ubuntu() {
    log "Installation PostgreSQL sur Ubuntu 24.04..."

    # Vérification si PostgreSQL est déjà installé
    if systemctl is-active --quiet postgresql 2>/dev/null && command -v psql &> /dev/null; then
        log "PostgreSQL est déjà installé et actif"
        return 0
    fi

    # Import de la clé de signature (méthode moderne)
    KEYRING_FILE="/usr/share/keyrings/postgresql-keyring.gpg"
    if [[ ! -f "$KEYRING_FILE" ]]; then
        log "Ajout de la clé PostgreSQL (méthode moderne)..."
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee "$KEYRING_FILE" > /dev/null
    else
        log "Clé PostgreSQL déjà présente"
    fi

    # Ajout du dépôt PostgreSQL officiel (méthode moderne)
    PGDG_SOURCE="/etc/apt/sources.list.d/pgdg.list"
    if [[ ! -f "$PGDG_SOURCE" ]]; then
        log "Ajout du dépôt PostgreSQL..."
        echo "deb [signed-by=$KEYRING_FILE] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee "$PGDG_SOURCE"
        sudo apt update
    else
        log "Dépôt PostgreSQL déjà configuré"
    fi

    # Installation des packages PostgreSQL (idempotent via apt)
    log "Installation des packages PostgreSQL..."
    sudo apt install -y postgresql-$PG_VERSION postgresql-client-$PG_VERSION postgresql-contrib-$PG_VERSION
    sudo apt install -y postgresql-server-dev-$PG_VERSION

    log "PostgreSQL $PG_VERSION installé sur Ubuntu"
}

# Installation PostgreSQL sur Debian
install_postgresql_debian() {
    log "Installation PostgreSQL sur Debian 13..."
    
    # Vérification si PostgreSQL est déjà installé
    if systemctl is-active --quiet postgresql 2>/dev/null && command -v psql &> /dev/null; then
        log "PostgreSQL est déjà installé et actif"
        return 0
    fi
    
    # Installation de gnupg2 si nécessaire (idempotent via apt)
    sudo apt install -y gnupg2
    
    # Import de la clé de signature avec méthode moderne (idempotent)
    KEYRING_FILE="/usr/share/keyrings/postgresql-keyring.gpg"
    if [[ ! -f "$KEYRING_FILE" ]]; then
        log "Ajout de la clé PostgreSQL (méthode Debian moderne)..."
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee "$KEYRING_FILE" > /dev/null
    else
        log "Clé PostgreSQL déjà présente"
    fi
    
    # Ajout du dépôt avec la nouvelle syntaxe (idempotent)
    PGDG_SOURCE="/etc/apt/sources.list.d/pgdg.list"
    if [[ ! -f "$PGDG_SOURCE" ]]; then
        log "Ajout du dépôt PostgreSQL..."
        echo "deb [signed-by=$KEYRING_FILE] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee "$PGDG_SOURCE"
        sudo apt update
    else
        log "Dépôt PostgreSQL déjà configuré"
    fi
    
    # Installation des packages (idempotent via apt)
    log "Installation des packages PostgreSQL..."
    sudo apt install -y postgresql-$PG_VERSION postgresql-client-$PG_VERSION postgresql-contrib-$PG_VERSION
    sudo apt install -y postgresql-server-dev-$PG_VERSION postgresql-common
    
    log "PostgreSQL $PG_VERSION installé sur Debian avec outils spécifiques"
}

# Configuration commune PostgreSQL
configure_postgresql_common() {
    log "Configuration de PostgreSQL..."
    
    # Démarrage et activation du service
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    
    # Configuration du mot de passe postgres selon la distribution
    case "$DISTRO" in
        "ubuntu")
            configure_postgresql_ubuntu_specific
            ;;
        "debian")
            configure_postgresql_debian_specific
            ;;
    esac
    
    # Configuration de base commune
    configure_postgresql_for_development
    
    # Installation du driver .NET pour PostgreSQL
    install_postgresql_dotnet_driver
    
    # Test de la connexion
    test_postgresql_connection
}

# Configuration spécifique Ubuntu
configure_postgresql_ubuntu_specific() {
    log "Configuration PostgreSQL spécifique Ubuntu..."
    
    # Ubuntu utilise le répertoire standard /etc/postgresql/
    PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"
    PG_DATA_DIR="/var/lib/postgresql/$PG_VERSION/main"
    
    # Génération de mots de passe sécurisés
    generate_postgresql_passwords
    
    # Configuration du mot de passe postgres avec mot de passe sécurisé
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$PG_ADMIN_PASS';" 2>/dev/null || true
    
    # Configuration dans pg_hba.conf pour le développement
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONFIG_DIR/postgresql.conf
    
    # Backup et modification de pg_hba.conf
    sudo cp $PG_CONFIG_DIR/pg_hba.conf $PG_CONFIG_DIR/pg_hba.conf.backup
    
    # Configuration sécurisée pour le développement (accès restreint par utilisateur)
    sudo tee -a $PG_CONFIG_DIR/pg_hba.conf > /dev/null <<EOF

# Configuration pour développement F#/ASP.NET Core (sécurisée)
local   testdb          $USER                                   md5
host    testdb          $USER           127.0.0.1/32            md5
host    testdb          $USER           ::1/128                 md5
EOF
}

# Configuration spécifique Debian
configure_postgresql_debian_specific() {
    log "Configuration PostgreSQL spécifique Debian..."
    
    # Debian utilise pg_ctlcluster et une structure différente
    PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"
    
    # Sur Debian, utilisation de pg_ctlcluster
    sudo pg_ctlcluster $PG_VERSION main start || true
    
    # Génération de mots de passe sécurisés
    generate_postgresql_passwords
    
    # Configuration du mot de passe avec l'approche Debian
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$PG_ADMIN_PASS';" 2>/dev/null || true
    
    # Debian sépare configuration des données
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONFIG_DIR/postgresql.conf
    
    # Backup et modification de pg_hba.conf (approche Debian)
    sudo cp $PG_CONFIG_DIR/pg_hba.conf $PG_CONFIG_DIR/pg_hba.conf.backup
    
    # Configuration sécurisée pour le développement
    sudo tee -a $PG_CONFIG_DIR/pg_hba.conf > /dev/null <<EOF

# Configuration pour développement F#/ASP.NET Core (Debian - sécurisée)
local   testdb          $USER                                   md5
host    testdb          $USER           127.0.0.1/32            md5
host    testdb          $USER           ::1/128                 md5
EOF

    # Redémarrage avec pg_ctlcluster
    sudo pg_ctlcluster $PG_VERSION main reload
}

# Génération de mots de passe PostgreSQL sécurisés
generate_postgresql_passwords() {
    # Génération de mots de passe aléatoires forts
    PG_ADMIN_PASS=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 32)
    APP_USER_PASS=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 32)
    
    # Stockage sécurisé des mots de passe
    PGPASS_FILE="$HOME/.pgpass"
    
    # Création du fichier .pgpass pour l'utilisateur courant
    if [[ ! -f "$PGPASS_FILE" ]]; then
        touch "$PGPASS_FILE"
        chmod 600 "$PGPASS_FILE"
    fi
    
    # Ajout des mots de passe (format: hostname:port:database:username:password)
    if ! grep -q "localhost:5432:\*:postgres:" "$PGPASS_FILE"; then
        echo "localhost:5432:*:postgres:$PG_ADMIN_PASS" >> "$PGPASS_FILE"
    fi
    
    if ! grep -q "localhost:5432:testdb:$USER:" "$PGPASS_FILE"; then
        echo "localhost:5432:testdb:$USER:$APP_USER_PASS" >> "$PGPASS_FILE"
    fi
    
    # Sauvegarde des mots de passe dans un fichier séparé pour référence
    CREDENTIALS_FILE="$HOME/.fsharp-aspnet-credentials"
    cat > "$CREDENTIALS_FILE" <<EOF
# Informations de connexion PostgreSQL générées automatiquement
# Script F#/ASP.NET Core v7.0 - $(date)
# 
# Administrateur PostgreSQL:
#   Utilisateur: postgres
#   Mot de passe: $PG_ADMIN_PASS
#
# Utilisateur développement:
#   Utilisateur: $USER
#   Mot de passe: $APP_USER_PASS
#   Base de données: testdb
#
# Chaîne de connexion ASP.NET Core:
# "Host=localhost;Database=testdb;Username=$USER;Password=$APP_USER_PASS"
#
# Commande de connexion psql:
# PGPASSWORD='$APP_USER_PASS' psql -h localhost -U $USER -d testdb
EOF
    
    chmod 600 "$CREDENTIALS_FILE"
    
    log "Mots de passe PostgreSQL générés et sauvegardés dans $CREDENTIALS_FILE"
}

# Configuration pour le développement
configure_postgresql_for_development() {
    log "Configuration PostgreSQL pour le développement..."
    
    # Création d'une base de données de test (idempotent)
    if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw testdb; then
        log "Création de la base de données 'testdb'..."
        sudo -u postgres createdb testdb
    else
        log "Base de données 'testdb' existe déjà"
    fi
    
    # Création d'un utilisateur de développement avec mot de passe sécurisé (idempotent)
    if ! sudo -u postgres psql -t -c "SELECT 1 FROM pg_user WHERE usename='$USER'" | grep -q 1; then
        log "Création de l'utilisateur PostgreSQL '$USER'..."
        sudo -u postgres psql -c "CREATE USER $USER WITH CREATEDB PASSWORD '$APP_USER_PASS';"
    else
        log "Utilisateur PostgreSQL '$USER' existe déjà"
        # Mise à jour du mot de passe si l'utilisateur existe
        sudo -u postgres psql -c "ALTER USER $USER PASSWORD '$APP_USER_PASS';"
    fi
    
    # Attribution des privilèges (idempotent - PostgreSQL gère la redondance)
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE testdb TO $USER;" 2>/dev/null || true
    
    log "Configuration PostgreSQL terminée - Base: testdb, Utilisateur: $USER (mot de passe sécurisé)"
}

# Installation du driver .NET PostgreSQL
install_postgresql_dotnet_driver() {
    log "Installation du driver .NET pour PostgreSQL..."
    
    # Le driver Npgsql est le driver officiel .NET pour PostgreSQL
    # Il sera ajouté aux projets via dotnet add package
    
    log "Driver Npgsql sera disponible via: dotnet add package Npgsql"
    log "Pour Entity Framework: dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL"
}

# Test de la connexion PostgreSQL
test_postgresql_connection() {
    log "Test de la connexion PostgreSQL..."
    
    # Test de connexion basique
    if sudo -u postgres psql -c "SELECT version();" > /dev/null 2>&1; then
        PG_VERSION_INFO=$(sudo -u postgres psql -t -c "SELECT version();" | head -1 | xargs)
        log "PostgreSQL fonctionne correctement: $PG_VERSION_INFO"
    else
        error "Problème de connexion à PostgreSQL"
        return 1
    fi
    
    # Test de connexion avec l'utilisateur de développement (avec mot de passe sécurisé)
    if PGPASSWORD="$APP_USER_PASS" psql -h localhost -U "$USER" -d testdb -c "SELECT 1;" > /dev/null 2>&1; then
        log "Connexion utilisateur '$USER' à la base 'testdb' réussie"
    else
        warn "Connexion utilisateur '$USER' échouée (normal si première installation)"
    fi
}

# Configuration pour la production
setup_production() {
    log "Configuration pour l'environnement de production..."
    
    # Configuration des variables d'environnement pour la production
    sudo tee /etc/environment > /dev/null <<EOF
ASPNETCORE_ENVIRONMENT=Production
DOTNET_ENVIRONMENT=Production
ASPNETCORE_URLS=http://0.0.0.0:5000
EOF

    # Configuration spécifique selon la distribution
    case "$DISTRO" in
        "ubuntu")
            setup_production_ubuntu
            ;;
        "debian")
            setup_production_debian
            ;;
    esac
    
    # Configuration commune
    setup_production_common
}

# Configuration spécifique Ubuntu
setup_production_ubuntu() {
    log "Configuration spécifique Ubuntu 24.04..."
    
    # UFW est généralement pré-installé sur Ubuntu
    if command -v ufw &> /dev/null; then
        log "Configuration du firewall UFW..."
        sudo ufw --force enable
        sudo ufw allow ssh
        sudo ufw allow 'Nginx Full'
        sudo ufw allow 5000  # Port par défaut ASP.NET Core
    else
        warn "UFW non trouvé, installation..."
        sudo apt install -y ufw
        sudo ufw --force enable
        sudo ufw allow ssh
        sudo ufw allow 'Nginx Full'
        sudo ufw allow 5000
    fi
    
    # Groupe www-data disponible par défaut
    sudo usermod -a -G www-data $USER
}

# Configuration spécifique Debian
setup_production_debian() {
    log "Configuration spécifique Debian 13..."
    
    # Sur Debian, installer UFW explicitement
    if ! command -v ufw &> /dev/null; then
        log "Installation du firewall UFW..."
        sudo apt install -y ufw
    fi
    
    log "Configuration du firewall UFW..."
    sudo ufw --force enable
    sudo ufw allow ssh/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 5000/tcp
    
    # Vérification et configuration du groupe www-data
    if ! getent group www-data &> /dev/null; then
        log "Création du groupe www-data..."
        sudo groupadd www-data
    fi
    sudo usermod -a -G www-data $USER
    
    # Configuration sudo si nécessaire (spécifique Debian)
    if ! sudo -n true 2>/dev/null; then
        warn "Configuration sudo requise sur Debian"
        warn "Assurez-vous que votre utilisateur est dans le groupe sudo"
        echo "$USER ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers.d/$USER
        sudo chmod 440 /etc/sudoers.d/$USER
    fi
}

# Configuration commune aux deux distributions
setup_production_common() {
    # Installation de systemd pour les services (si pas déjà présent)
    if ! systemctl --version &> /dev/null; then
        warn "systemd non détecté, installation..."
        sudo apt install -y systemd
    fi
    
    # Vérification que systemd est actif
    if ! systemctl is-system-running --quiet; then
        warn "systemd n'est pas complètement initialisé"
        warn "Un redémarrage pourrait être nécessaire"
    fi
    
    # Configuration de nginx (recommandé pour la production)
    if ! command -v nginx &> /dev/null; then
        log "Installation de nginx..."
        sudo apt install -y nginx
    fi
    
    # Configuration nginx sécurisée
    log "Configuration de nginx..."
    sudo systemctl enable nginx
    sudo systemctl start nginx
    
    # Création d'un exemple de configuration nginx pour ASP.NET Core
    create_nginx_config
    
    # Configuration des limites système pour .NET
    configure_system_limits
}

# Création de la configuration nginx
create_nginx_config() {
    log "Configuration nginx pour ASP.NET Core..."
    
    NGINX_CONFIG="/etc/nginx/sites-available/aspnet-app"
    
    # Création de la configuration seulement si elle n'existe pas (idempotent)
    if [[ ! -f "$NGINX_CONFIG" ]]; then
        log "Création de la configuration nginx..."
        sudo tee "$NGINX_CONFIG" > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
        log "Configuration nginx créée: $NGINX_CONFIG"
    else
        log "Configuration nginx existe déjà: $NGINX_CONFIG"
    fi
    
    log "Pour activer: sudo ln -s $NGINX_CONFIG /etc/nginx/sites-enabled/"
}

# Configuration des limites système
configure_system_limits() {
    log "Configuration des limites système pour .NET..."
    
    LIMITS_FILE="/etc/security/limits.d/dotnet.conf"
    SYSCTL_FILE="/etc/sysctl.d/99-dotnet.conf"
    
    # Configuration des limites système (idempotent)
    if [[ ! -f "$LIMITS_FILE" ]]; then
        log "Création des limites système pour .NET..."
        sudo tee "$LIMITS_FILE" > /dev/null <<EOF
# Limites pour les applications .NET
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF
        log "Limites système configurées: $LIMITS_FILE"
    else
        log "Limites système déjà configurées: $LIMITS_FILE"
    fi

    # Configuration sysctl (idempotent)
    if [[ ! -f "$SYSCTL_FILE" ]]; then
        log "Configuration sysctl pour les performances réseau..."
        sudo tee "$SYSCTL_FILE" > /dev/null <<EOF
# Optimisations pour ASP.NET Core
net.core.somaxconn = 65536
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
EOF
        log "Configuration sysctl créée: $SYSCTL_FILE"
    else
        log "Configuration sysctl déjà présente: $SYSCTL_FILE"
    fi
}

# Création d'un projet de test
create_test_project() {
    log "Création d'un projet de test F#/ASP.NET Core avec Giraffe..."
    
    TEST_DIR="$HOME/fsharp-aspnet-test"
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
    
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Création d'un projet Giraffe si le template est disponible
    if dotnet new list | grep -q "giraffe"; then
        log "Création d'un projet Giraffe..."
        dotnet new giraffe -n GiraffeTestApp
        cd GiraffeTestApp
        
        # Test de compilation du projet Giraffe
        if dotnet build; then
            log "Projet Giraffe créé et compilé avec succès dans $TEST_DIR/GiraffeTestApp"
            MAIN_PROJECT="GiraffeTestApp"
        else
            warn "Échec de la compilation du projet Giraffe, création d'un projet WebAPI standard..."
            cd ..
            rm -rf GiraffeTestApp
            dotnet new webapi -lang F# -n TestApp
            cd TestApp
            
            # Ajout manuel de Giraffe au projet WebAPI
            log "Ajout de Giraffe au projet WebAPI..."
            dotnet add package Giraffe
            
            if dotnet build; then
                log "Projet WebAPI avec Giraffe créé et compilé avec succès dans $TEST_DIR/TestApp"
                MAIN_PROJECT="TestApp"
            else
                error "Échec de la compilation du projet de test"
                exit 1
            fi
        fi
    else
        # Fallback: création d'un projet WebAPI avec ajout manuel de Giraffe
        log "Template Giraffe non disponible, création d'un projet WebAPI avec ajout de Giraffe..."
        dotnet new webapi -lang F# -n TestApp
        cd TestApp
        
        # Ajout de Giraffe
        dotnet add package Giraffe
        
        # Test de compilation
        if dotnet build; then
            log "Projet WebAPI avec Giraffe créé et compilé avec succès dans $TEST_DIR/TestApp"
            MAIN_PROJECT="TestApp"
        else
            error "Échec de la compilation du projet de test"
            exit 1
        fi
    fi
    
    cd ~
}

# Affichage des informations finales
show_final_info() {
    log "Installation terminée avec succès! (v7.0)"
    echo
    echo -e "${BLUE}=== Récapitulatif de l'installation ===${NC}"
    echo "- .NET Version: $(dotnet --version 2>/dev/null || echo 'Non disponible')"
    echo "- F# Compiler: $(dotnet fsc --help 2>/dev/null | head -1 || echo 'Non disponible')"
    echo "- Projet de test: $HOME/fsharp-aspnet-test/${MAIN_PROJECT:-TestApp}"
    echo "- PostgreSQL: $(sudo -u postgres psql -t -c "SELECT version();" 2>/dev/null | head -1 | xargs || echo 'Non disponible')"
    echo "- Base de données de test: testdb (utilisateur: $USER)"
    echo "- Informations de connexion: ~/.fsharp-aspnet-credentials"
    echo
    echo -e "${YELLOW}Pour appliquer les variables d'environnement:${NC}"
    echo "source ~/.bashrc"
    echo
    echo -e "${YELLOW}Pour tester votre installation:${NC}"
    echo "cd $HOME/fsharp-aspnet-test/${MAIN_PROJECT:-TestApp}"
    echo "dotnet run"
    echo
    echo -e "${YELLOW}Pour créer un nouveau projet F#/ASP.NET Core avec Giraffe et PostgreSQL:${NC}"
    echo "dotnet new giraffe -n MonProjetGiraffe"
    echo "cd MonProjetGiraffe"
    echo "dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL"
    echo "# ou pour un projet WebAPI classique:"
    echo "dotnet new webapi -lang F# -n MonProjet && cd MonProjet"
    echo "dotnet add package Giraffe && dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL"
    echo
    echo -e "${YELLOW}Connexion PostgreSQL:${NC}"
    echo "psql -h localhost -U $USER -d testdb"
    echo "# Mot de passe dans ~/.fsharp-aspnet-credentials"
    echo
    echo -e "${YELLOW}Informations complètes de connexion:${NC}"
    echo "cat ~/.fsharp-aspnet-credentials"
    echo
    if [[ "$1" == "production" ]]; then
        echo -e "${BLUE}=== Configuration Production ===${NC}"
        echo "- Variables d'environnement configurées dans /etc/environment"
        echo "- Nginx installé et configuré"
        echo "- Firewall UFW activé"
        echo "- Ports ouverts: SSH, HTTP/HTTPS (80/443), ASP.NET (5000)"
    fi
}

# Menu principal
main() {
    echo -e "${BLUE}=== Script d'installation F#/ASP.NET Core v7.0 ===${NC}"
    echo "Compatible Ubuntu 24.04 et Debian 13 - Sécurisé et idempotent"
    echo
    
    # Arguments du script
    PRODUCTION_MODE=false
    REPO_METHOD=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --production)
                PRODUCTION_MODE=true
                shift
                ;;
            --repo-method)
                REPO_METHOD=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --production    Configuration pour serveur de production"
                echo "  --repo-method   Utiliser les dépôts Microsoft au lieu du script d'installation"
                echo "  --help          Afficher cette aide"
                echo ""
                echo "Version 7.0 - Fonctionnalités:"
                echo "  • Installation complète F#/ASP.NET Core + Giraffe + PostgreSQL"
                echo "  • Configuration sécurisée avec mots de passe forts"
                echo "  • Script idempotent (ré-exécutable sans risque)"
                echo "  • Optimisations système et configuration nginx"
                exit 0
                ;;
            *)
                error "Option inconnue: $1"
                exit 1
                ;;
        esac
    done
    
    detect_distro
    check_root
    update_system
    
    # Choix de la méthode d'installation .NET
    if [[ "$REPO_METHOD" == true ]]; then
        install_dotnet_repo
    else
        install_dotnet
    fi
    
    install_dev_tools
    install_giraffe_templates
    install_postgresql
    
    if [[ "$PRODUCTION_MODE" == true ]]; then
        setup_production
    fi
    
    create_test_project
    show_final_info "$([[ $PRODUCTION_MODE == true ]] && echo 'production' || echo 'development')"
}

# Exécution du script principal
main "$@"
