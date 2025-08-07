# dotnet-fsharp-pg.sh

[![Bash Script](https://img.shields.io/badge/Bash-%3E%3D5.2-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Ubuntu 24.04](https://img.shields.io/badge/Ubuntu-24.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Debian 13](https://img.shields.io/badge/Debian-13-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![.NET LTS](https://img.shields.io/badge/.NET-LTS-512BD4?logo=dotnet&logoColor=white)](https://dotnet.microsoft.com/)
[![PostgreSQL 17](https://img.shields.io/badge/PostgreSQL-17-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Idempotent](https://img.shields.io/badge/Idempotent-yes-blueviolet)]()
[![Secure](https://img.shields.io/badge/Security-hardened-00796B?logo=security&logoColor=white)]()

Script Bash d’installation automatisée d’un environnement F#/ASP.NET Core + Giraffe + PostgreSQL sur **Ubuntu 24.04** et **Debian 13 (Trixie)**.

## Fonctionnalités

- Installation du SDK .NET (dernière version LTS)
- Templates et outils F# (FSAutoComplete, Fantomas, FSharp.Analyzers)
- Framework web Giraffe (version LTS)
- PostgreSQL 17 avec configuration sécurisée (mots de passe forts, pg_hba.conf restrictif)
- Configuration nginx pour reverse proxy
- Optimisations système pour ASP.NET Core (sysctl, limites)
- Script idempotent et sécurisé
- Nettoyage automatique et gestion d’erreurs robuste

## Usage

1. **Rendez le script exécutable** :
   ```bash
   chmod +x dotnet-fsharp-pg.sh
   ```

2. **Lancez le script** :
   ```bash
   ./dotnet-fsharp-pg.sh
   ```

   - Mode production :  
     ```bash
     ./dotnet-fsharp-pg.sh --production
     ```
   - Utiliser les dépôts Microsoft pour .NET :  
     ```bash
     ./dotnet-fsharp-pg.sh --repo-method
     ```
   - Afficher l’aide :  
     ```bash
     ./dotnet-fsharp-pg.sh --help
     ```

3. **Après installation** :  
   Pour appliquer les variables d’environnement immédiatement :
   ```bash
   source ~/.bashrc
   ```

## Informations de connexion

- Les mots de passe PostgreSQL sont générés et stockés dans :  
  `~/.fsharp-aspnet-credentials`
- Fichier `.pgpass` créé pour la connexion automatique avec `psql`.

## Exemples de commandes

- Lancer le projet de test :
  ```bash
  cd ~/fsharp-aspnet-test/GiraffeTestApp
  dotnet run
  ```
- Créer un nouveau projet Giraffe :
  ```bash
  dotnet new giraffe -n MonProjetGiraffe
  cd MonProjetGiraffe
  dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
  ```

## Prérequis

- Ubuntu 24.04 ou Debian 13 (Trixie)
- Accès sudo

## Sécurité

- Ne pas lancer le script en tant que root.
- Les accès PostgreSQL sont restreints et les mots de passe forts.

---

_Auteur : Assistant Claude / GitHub Copilot_