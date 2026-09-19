# Projet d'évaluation : Cloud, Floci et Terraform

Ce projet déploie deux services Cloud avec **Terraform** sur un environnement Cloud
local fourni par **Floci**. Ce README est complété au fil des étapes et permet de
reproduire le projet.


## Sommaire

- [Provider choisi](#provider-choisi)
- [Prérequis](#prérequis)
- [Étape 1 : Installation et lancement de Floci](#étape-1--installation-et-lancement-de-floci)
- [Dépannage](#dépannage)
- [Notes](#notes)
- [Références](#références)

## Provider choisi

- **Provider : AWS**, émulé localement par Floci.
- **Services :** ils seront choisis et justifiés à l'étape 3, après l'exploration de
  Floci UI.

## Prérequis

- Windows avec **WSL2 (Ubuntu)** ; toutes les commandes sont exécutées dans le terminal
  Ubuntu, depuis `~/cloud-project`
- **Docker Desktop** avec l'intégration WSL activée (Docker 28.5.1)
- Une connexion Internet (téléchargement du CLI et de l'image Docker)

## Étape 1 : Installation et lancement de Floci

### 1. Installer Floci

```bash
curl -fsSL https://floci.io/install.sh | sh
```

Méthode officielle de <https://floci.io/>. Le script télécharge le CLI `floci`,
vérifie son checksum et l'installe dans `/usr/local/bin` (d'où le `sudo`).

```text
Downloading floci 0.2.3 for linux-amd64...
Checksum verified.
Installing to /usr/local/bin requires sudo...
Floci CLI 0.2.3 installed to /usr/local/bin/floci
```

### 2. Démarrer Floci

```bash
floci start
```

```text
Checking image floci/floci:latest (policy: missing)...
[...]
Status: Downloaded newer image for floci/floci:latest
Starting Floci AWS container...
Container started (9df8951db794)
Waiting for Floci AWS to be ready...
Floci AWS is ready (http://localhost:4566)
```

Le CLI télécharge l'image Docker `floci/floci` (seulement si elle est absente), puis
lance un conteneur nommé `floci`.

### 3. Configurer le terminal

```bash
eval $(floci env)
```

Cette commande exporte dans le terminal courant les variables d'environnement AWS
pointant vers Floci (endpoint local, région, identifiants factices). Elles sont perdues
à la fermeture du terminal.

### 4. Identifier le port du provider choisi

Le provider se choisit par la commande de démarrage du CLI :

| Provider | Commande | Port |
|---|---|---|
| **AWS** (choisi) | `floci start` | **4566** |
| Azure | `floci az start` | 4577 |
| GCP | `floci gcp start` | 4588 |
| OCI | `floci oci start` | 4599 |

En lançant `floci start`, j'ai démarré l'émulateur **AWS**, accessible sur
**http://localhost:4566**.

### 5. Vérifier que le service fonctionne

**Diagnostic du CLI**

```bash
floci doctor
```

```text
Floci AWS Doctor — checking your environment

  ✓ docker.installed           Docker 28.5.1 detected
  ✓ docker.daemon              Daemon reachable
  ✓ docker.socket              /var/run/docker.sock accessible
  ✓ docker.version             Docker 28.5.1 (>= 20.10)
  ✓ port.available             Port 4566 in use by container 'floci' (expected)
  ✓ image.present              floci/floci image present locally
  ✓ image.version              Server image version 2.1.0 (>= 1.5.0)
  ✓ container.running          Container 'floci' is running
  ✓ endpoint.reachable         http://localhost:4566 is reachable (server v2.1.0)
  ✓ aws.cli.endpoint           aws CLI not installed — skipped
  ✓ aws.cli.s3.pathstyle       ~/.aws/config not found — skipped

All checks passed.
```

**État du conteneur**

```bash
docker ps
```

```text
CONTAINER ID   IMAGE                COMMAND                  CREATED          STATUS                    PORTS                                         NAMES
9df8951db794   floci/floci:latest   "/usr/local/bin/dock…"   10 minutes ago   Up 10 minutes (healthy)   0.0.0.0:4566->4566/tcp, [::]:4566->4566/tcp   floci
```

Le conteneur `floci` est `Up (healthy)` et le port 4566 est publié.

**Réponse de l'API**

```bash
curl http://localhost:4566/_floci/health
```

```text
{"version":"2.1.0","edition":"community","services":{"ssm":"running","sqs":"running","s3":"running","dynamodb":"running", ...
```

*(sortie abrégée)* Le serveur répond en version 2.1.0 et tous les services listés,
dont `s3`, `dynamodb` et `secretsmanager`, sont en `running`.

**Navigateur** : <http://localhost:4566> affiche la page d'accueil de Floci
(statut **ready**, région `us-east-1`, version `2.1.0`, **121 services running**).

### Captures d'écran

- Floci dans le navigateur : [screenshots/floci.png](screenshots/floci.png)
- Floci dans le terminal (`floci doctor` et `docker ps`) : [screenshots/floci-terminal.png](screenshots/floci-terminal.png)

![Floci dans le navigateur](screenshots/floci.png)

![Floci dans le terminal](screenshots/floci-terminal.png)

## Dépannage

**`floci start` : `lookup registry-1.docker.io: no such host`**
Docker ne pouvait pas télécharger l'image depuis Docker Hub : c'était un problème de
connexion Internet (DNS), pas de Floci. Après rétablissement de la connexion,
`floci start` a fonctionné.

## Notes

- Le fichier `.terraform.lock.hcl` est **versionné** (il n'est pas dans le `.gitignore`),
  conformément à la documentation Terraform : il garantit les mêmes versions de provider
  pour tous.

## Références

- Floci : <https://floci.io/> et <https://github.com/floci-io/floci>
- Floci CLI : <https://github.com/floci-io/floci-cli>
- Floci UI : <https://github.com/floci-io/floci-ui>
- Terraform : <https://developer.hashicorp.com/terraform/docs>
- Dependency Lock File : <https://developer.hashicorp.com/terraform/language/files/dependency-lock>