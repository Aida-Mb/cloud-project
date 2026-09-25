# Projet d'évaluation : Cloud, Floci et Terraform

Ce projet déploie deux services Cloud avec **Terraform** sur un environnement Cloud
local fourni par **Floci**. Ce README est complété au fil des étapes et permet de
reproduire le projet.


## Sommaire

- [Provider choisi](#provider-choisi)
- [Prérequis](#prérequis)
- [Étape 1 : Installation et lancement de Floci](#étape-1--installation-et-lancement-de-floci)
- [Étape 2 : Lancement de Floci UI](#étape-2--lancement-de-floci-ui)
- [Étape 3 : Choix du provider et des services](#étape-3--choix-du-provider-et-des-services)
- [Étape 4 : Création du projet Terraform](#étape-4--création-du-projet-terraform)
- [Étape 5 : Configuration du provider](#étape-5--configuration-du-provider)
- [Étapes 6 à 8 : Variables, `terraform.tfvars` et `locals`](#étapes-6-à-8--variables-terraformtfvars-et-locals)
- [Étape 9 : Création des modules](#étape-9--création-des-modules)
- [Étape 10 : Outputs](#étape-10--outputs)
- [Étape 11 : Validation et déploiement](#étape-11--validation-et-déploiement)
- [Étape 12 : Destruction](#étape-12--destruction)
- [Notes](#notes)
- [Références](#références)

## Provider choisi

- **Provider : AWS**, émulé localement par Floci.
- **Service 1 : Amazon S3** (stockage d'objets), déployé avec le module `storage`.
- **Service 2 : Amazon DynamoDB** (base de données NoSQL clé-valeur), déployé avec le module `database`.

**Pourquoi ces deux services :**

- **Supportés par Floci** : l'API de santé (`/_floci/health`) indique `s3` et `dynamodb`
  en `running`.
- **Visibles dans Floci UI** : la console propose une page **Storage** (S3) et une page
  **DynamoDB**, ce qui permet de vérifier les ressources après `terraform apply` puis
  après `terraform destroy`, comme le demande le sujet.
- **Complémentaires** : deux modèles de données différents, des objets (fichiers) d'un
  côté, des enregistrements clé-valeur de l'autre.
- **Simples à décrire avec Terraform** : une ressource principale chacun
  (`aws_s3_bucket`, `aws_dynamodb_table`), ce qui permet de se concentrer sur
  l'organisation du projet (modules, variables, locals, outputs).


---

## Prérequis

- Windows avec **WSL2 (Ubuntu)** ; toutes les commandes sont exécutées dans le terminal
  Ubuntu, depuis `~/cloud-project`
- **Docker Desktop** avec l'intégration WSL activée (Docker 28.5.1)
- **Terraform** v1.16.3 (installé via le dépôt officiel de HashiCorp, voir
  [Étape 4](#étape-4--création-du-projet-terraform))
- Une connexion Internet (téléchargement du CLI Floci, de l'image Docker, du provider
  Terraform)

---

## Étape 1 : Installation et lancement de Floci

Floci se compose de deux éléments : le **CLI `floci`**, un outil en ligne de commande
qui pilote l'émulateur, et l'**émulateur** lui-même, qui tourne dans un conteneur Docker
(image `floci/floci`). On installe d'abord le CLI, puis on lui demande de démarrer
l'émulateur.

### 1. Installer le CLI Floci

```bash
curl -fsSL https://floci.io/install.sh | sh
```

Méthode officielle indiquée sur <https://floci.io/>. `curl` télécharge le script
d'installation (`-f` échoue en cas d'erreur HTTP, `-s` reste silencieux, `-S` affiche
tout de même les erreurs, `-L` suit les redirections) et `| sh` l'exécute directement.

![Installation du CLI Floci](screenshots/etape1/install-cli.png)

**Ce que montre la capture :**

- `Downloading floci 0.2.3 for linux-amd64` : le script a détecté mon système (Linux) et
  mon architecture (amd64), puis a choisi le binaire correspondant, en version **0.2.3**.
- `Checksum verified` : l'empreinte (checksum) du fichier téléchargé correspond à
  l'empreinte attendue ; le binaire n'est ni corrompu ni altéré.
- `Installing to /usr/local/bin requires sudo` : `/usr/local/bin` est un dossier système,
  réservé à l'administrateur, d'où la demande du mot de passe (`[sudo] password`). Le
  dossier fait partie du `PATH`, donc la commande `floci` est utilisable depuis
  n'importe quel répertoire.
- `Floci CLI 0.2.3 installed to /usr/local/bin/floci` : l'installation est terminée.

### 2. Démarrer Floci

```bash
floci start
```

![Démarrage de Floci](screenshots/etape1/floci-start.png)

**Ce que montre la capture :**

- `Checking image floci/floci:latest (policy: missing)` : le CLI cherche l'image Docker
  de l'émulateur. La politique `missing` signifie qu'elle n'est téléchargée **que si
  elle est absente** de la machine.
- `Pulling from floci/floci` et les lignes `Pull complete` : une image Docker est
  composée de couches (*layers*) téléchargées séparément ; chaque `Pull complete`
  indique qu'une couche est prête.
- `Digest: sha256:f5aa8c18…` : empreinte unique de la version exacte de l'image
  téléchargée.
- `Status: Downloaded newer image for floci/floci:latest` : l'image a bien été
  téléchargée (c'est le premier lancement).
- `Starting Floci AWS container...` puis `Container started (9df8951db794)` : le
  conteneur est créé et démarré ; `9df8951db794` est son identifiant.
- `Floci AWS is ready (http://localhost:4566)` : le CLI a attendu que l'émulateur
  réponde et donne son adresse.

Le mot **AWS** dans ces messages confirme que c'est l'émulateur du provider choisi qui
a été lancé.

### 3. Identifier le port utilisé par le provider choisi

Le CLI Floci choisit le provider **par la commande de démarrage** :

| Provider | Commande de démarrage | Port |
|---|---|---|
| **AWS** (choisi) | `floci start` | **4566** |
| Azure | `floci az start` | 4577 |
| GCP | `floci gcp start` | 4588 |
| OCI | `floci oci start` | 4599 |

Chaque provider est un émulateur distinct, avec sa propre image et son propre port. En
lançant `floci start` sans sous-commande, j'ai démarré l'émulateur **AWS**, dont le
port est **4566**. Je le vérifie avec Docker :

```bash
docker port floci
```

![Ports publiés par le conteneur floci](screenshots/etape1/docker-port.png)

**Ce que montre la capture :** la commande affiche les ports que le conteneur `floci`
expose sur ma machine. La ligne `4566/tcp -> 0.0.0.0:4566` signifie que le port 4566
(TCP) du conteneur est accessible sur le port 4566 de ma machine, sur toutes les
interfaces IPv4 ; la ligne `[::]:4566` correspond à la même chose en IPv6. Le port de
l'émulateur AWS est donc bien **4566**.

### 4. Configurer le terminal

```bash
eval $(floci env)
env | grep -i aws | grep -viE 'key|secret|token'
```

`floci env` affiche des commandes `export` ; `eval` les exécute dans le terminal
courant, ce qui explique que la première commande n'affiche rien. La seconde vérifie le
résultat en deux filtres :

- `env` liste toutes les variables d'environnement, et `grep -i aws` ne garde que les
  lignes contenant « aws » (sans tenir compte de la casse) ;
- `grep -viE 'key|secret|token'` **exclut** ensuite toute ligne contenant « key »,
  « secret » ou « token », pour ne jamais afficher d'identifiants.

Ce second filtre est volontaire : par bonne pratique, aucun identifiant ne doit figurer
dans un README ou une capture d'écran. Ici les identifiants définis par Floci sont
factices, mais la même commande sans filtre afficherait de vraies clés AWS si j'en avais
configuré sur ma machine.

![Variables d'environnement AWS définies par floci env (identifiants masqués)](screenshots/etape1/floci-env.png)

**Ce que montre la capture :** les variables non sensibles définies par `floci env`.
 On y retrouve :

- `AWS_ENDPOINT_URL=http://localhost:4566` : l'adresse à laquelle les outils AWS envoient
  leurs requêtes. C'est cette variable qui les redirige vers Floci au lieu du vrai AWS
  (notion d'**endpoint local**) ;
- la région par défaut (`us-east-1`).

`floci env` définit aussi un identifiant d'accès et une clé secrète, volontairement non
affichés. Selon la documentation de Floci, ce sont des valeurs **factices** : l'émulateur
accepte n'importe quelle valeur non vide, donc aucun vrai compte n'est utilisé. Avec le
vrai AWS, en revanche, ces clés sont de vrais secrets qu'il ne faut jamais commiter, ce
que le `.gitignore` du projet prévoit (`*.pem`, `*.key`, fichiers d'identifiants).

Ces variables sont perdues à la fermeture du terminal : il faut relancer
`eval $(floci env)` dans chaque nouveau terminal.

### 5. Vérifier que le service fonctionne

La vérification est faite à quatre niveaux, du plus technique au plus visuel.

#### a) Diagnostic du CLI

```bash
floci doctor
```

![Résultat de floci doctor](screenshots/etape1/floci-doctor.png)

**Ce que montre la capture :** onze contrôles, tous marqués ✓, et le message
`All checks passed.` En détail :

- `docker.installed`, `docker.daemon`, `docker.version` : Docker 28.5.1 est installé, son
  service répond, et sa version est suffisante (≥ 20.10 requis).
- `docker.socket` : le socket `/var/run/docker.sock` est accessible. Floci en a besoin
  pour piloter Docker (il lance ses conteneurs et certains services).
- `port.available` : le port 4566 est déjà utilisé, mais par le conteneur `floci`
  lui-même, ce qui est le comportement attendu (`expected`).
- `image.present` et `image.version` : l'image `floci/floci` est présente localement et le
  serveur est en version **2.1.0** (≥ 1.5.0 requis).
- `container.running` : le conteneur `floci` tourne.
- `endpoint.reachable` : `http://localhost:4566` répond (serveur v2.1.0).
- `aws.cli.endpoint`, `aws.cli.s3.pathstyle` : ignorés (`skipped`) car le CLI AWS n'est
  pas installé ; cela n'empêche pas Floci de fonctionner.

#### b) État du conteneur Docker

```bash
docker ps
```

![Conteneur floci dans docker ps](screenshots/etape1/docker-ps.png)

**Ce que montre la capture :** la liste des conteneurs en cours d'exécution, avec une
seule ligne, `floci` :

- `IMAGE floci/floci:latest` : l'image utilisée ;
- `STATUS Up … (healthy)` : le conteneur tourne et son contrôle de santé interne réussit ;
- `PORTS 0.0.0.0:4566->4566/tcp, [::]:4566->4566/tcp` : le port 4566 est publié (IPv4
  et IPv6), ce qui confirme la vérification de l'étape 3 ;
- `NAMES floci` : nom du conteneur.

#### c) Réponse de l'API de santé

```bash
curl http://localhost:4566/_floci/health
```

![Réponse de l'API de santé de Floci](screenshots/etape1/health.png)

**Ce que montre la capture :** `curl` envoie une requête HTTP à l'émulateur, qui répond
en JSON :

- `"version":"2.1.0"` : version du serveur Floci ;
- `"edition":"community"` : édition gratuite ;
- `"services":{…}` : l'état de chaque service émulé. `"running"` signifie que le service
  est démarré et prêt. On y trouve notamment `s3`, `dynamodb` et `secretsmanager`, qui
  pourront servir au projet.

#### d) Page d'accueil dans le navigateur

Ouvrir <http://localhost:4566> dans le navigateur.

![Floci en fonctionnement dans le navigateur](screenshots/floci.png)

**Ce que montre la capture :**

- `ready` : l'émulateur est prêt ;
- `Endpoint http://localhost:4566` : l'adresse et le port de l'API ;
- `Region us-east-1 (default)` : région par défaut de l'émulateur ;
- `Account 000000000000` : identifiant de compte par défaut. Floci l'utilise lorsque la
  clé d'accès n'est pas un identifiant de 12 chiffres, ce qui est le cas de `test` ;
- `Version 2.1.0 · community` : version et édition du serveur ;
- `Services 121 running · 0 available` : 121 services émulés, tous démarrés.

Floci (AWS) est installé, démarré
dans le conteneur `floci`, joignable sur le port **4566**, et ses services sont
opérationnels.


---

## Étape 2 : Lancement de Floci UI

**Floci UI** est une console web, dans le style de la console AWS, qui permet
d'explorer les services de l'environnement local. Dans ce projet, elle sert à
**explorer et vérifier** les ressources : celles-ci seront créées avec Terraform, pas
depuis l'interface.

### 1. Lancer Floci UI

Aucune installation supplémentaire n'est nécessaire : Floci lance l'interface à la
demande. Depuis la page d'accueil de Floci (<http://localhost:4566>), cliquer sur le
bouton **Open Floci UI**.

![Bouton d'ouverture de Floci UI sur la page d'accueil de Floci](screenshots/etape2/open-ui-button.png)

**Ce que montre la capture :** en bas de la page, une note indique que l'interface
utilisateur se lance à la demande, sous forme de **conteneur annexe (*sidecar*)**, lors
de la première ouverture. Floci démarre donc lui-même un second conteneur pour l'UI. Cela
est possible car Floci a accès au socket Docker de la machine (contrôle `docker.socket` de
`floci doctor` à l'étape 1).

Vérification :

```bash
docker ps
```

![Conteneurs floci et floci-ui dans docker ps](screenshots/etape2/docker-ps.png)

**Ce que montre la capture :** deux conteneurs actifs.

- `floci` (image `floci/floci:latest`) : l'émulateur AWS, port **4566**, actif depuis
  l'étape 1 et `healthy`.
- `floci-ui` : l'interface web, port **4500** (`0.0.0.0:4500->4500/tcp`), créé quelques
  minutes plus tôt, au moment du clic sur le bouton. Sa présence confirme le mécanisme
  de conteneur annexe.

### 2. Accéder à l'interface Web

Ouvrir <http://localhost:4500> : la console redirige vers
`http://localhost:4500/console/aws`.

![Accueil de la console Floci UI, provider AWS](screenshots/floci-ui.png)

**Ce que montre la capture :** la page **Console Home**, accueil de la console.

- **Connexion** : l'indicateur vert *Connected* affiche `http://172.17.0.2:4566`. C'est
  l'adresse de l'émulateur telle que la voit le conteneur `floci-ui` : l'IP du conteneur
  `floci` sur le réseau interne de Docker. Depuis l'intérieur du conteneur de l'UI,
  `localhost` désignerait le conteneur de l'UI lui-même, d'où cette adresse.
- **Compte** : `0000-0000-0000`, identifiant de compte factice de l'émulateur (le même
  que `000000000000` sur la page d'accueil de Floci).
- **Chaîne de fonctionnement** : les quatre cartes sous le bandeau détaillent le trajet
  d'une requête : interface *Console Home* → proxy `/api/clouds` → adaptateur *AWS* →
  runtime *Floci AWS Core*.

### 3. Identifier le Cloud Provider choisi

Le provider choisi est **AWS** (voir la capture ci-dessus) :

- le sélecteur de cloud en haut à droite propose **AWS**, Azure et GCP ; **AWS** est
  sélectionné ;
- le bandeau indique **AWS Local Runtime**, et la carte *Cloud* affiche AWS avec l'endpoint
  `http://172.17.0.2:4566` ;
- la barre latérale liste les services du provider (section *Cloud Services · AWS*) ;
- l'URL contient le provider : `/console/aws`.

Azure et GCP sont proposés par l'interface mais dépendent d'émulateurs distincts
(`floci az`, `floci gcp`) qui ne sont pas lancés dans ce projet.

### 4. Explorer les services disponibles

La page d'accueil résume l'état du runtime : *Reachable runtime* (l'émulateur répond),
**19 services actifs sur 21 disponibles**, et **13 ressources** déjà présentes avant tout
déploiement. Elles ne viennent pas de mon projet : c'est l'état de référence de
l'environnement.

La barre latérale liste les services, regroupés par catégorie :

| Catégorie | Services affichés |
|---|---|
| Compute | Compute, EKS, Serverless, Containers *(bientôt disponible)* |
| Storage | **Storage** (S3) |
| Databases | Database, **DynamoDB** |
| Networking | Networking, ELB |
| Integration | SQS, API Gateway, EventBridge, Step Functions, Cloud Scheduler *(bientôt disponible)* |
| Provisioning | CloudFormation |

Chaque service disponible est aussi représenté par une carte sur la page d'accueil
(*available*). Deux entrées portent la mention *coming soon* : Containers et Cloud
Scheduler.

### 5. Identifier les deux services du projet Terraform

Les deux services retenus (voir [Provider choisi](#provider-choisi)) se retrouvent dans
la console :

| Service Terraform | Page de la console Floci UI |
|---|---|
| Amazon S3 | **Storage** |
| Amazon DynamoDB | **DynamoDB** |

> Remarque : le README du dépôt `floci-ui` indique que DynamoDB n'est pas encore intégré
> à la vue unifiée *Cloud Explorer*. Dans la version installée ici, DynamoDB dispose
> néanmoins d'une entrée dédiée dans la barre latérale, ce qui permet de l'utiliser pour
> la vérification.

---


## Étape 3 : Choix du provider et des services

Le choix (AWS, avec Amazon S3 et Amazon DynamoDB) et sa justification figurent dans la
section [Provider choisi](#provider-choisi).

---

## Étape 4 : Création du projet Terraform

### 1. Installer Terraform

Procédure officielle de HashiCorp, tutoriel *Install Terraform*
(onglet *Package manager*, puis *Linux*, puis *Ubuntu/Debian*) :
<https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli>

Terraform est installé depuis le **dépôt de paquets officiel de HashiCorp** : les paquets
sont signés, et `apt` pourra ensuite proposer les mises à jour.

#### a) Préparer le système

```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
```



**Durant l'installation on voit :**

- `apt-get update` rafraîchit la liste des paquets disponibles depuis les dépôts Ubuntu
  (`noble` est le nom de code d'Ubuntu 24.04).
- `gnupg is already the newest version` : `gnupg` était déjà installé et à jour. Il sert
  à vérifier la signature des paquets HashiCorp.
- `2 upgraded, 0 newly installed` : `software-properties-common` (et sa dépendance
  `python3-software-properties`) est passé de la version 0.99.49.2 à 0.99.49.4. Ce paquet
  fournit les outils de gestion des dépôts `apt`. Les 82 autres mises à jour disponibles
  ne sont pas touchées.
- Les messages `debconf: unable to initialize frontend: Dialog` sont sans gravité : la
  fenêtre du terminal est trop petite pour l'interface Dialog, `debconf` bascule donc sur
  une interface en ligne (`Readline`) et l'installation continue.

#### b) Ajouter et vérifier la clé de signature de HashiCorp

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
```

Ce que fait cette commande, en trois temps :

1. `wget -O-` télécharge la clé publique de HashiCorp et l'envoie sur la sortie standard.
2. `gpg --dearmor` la convertit du format texte au format binaire attendu par `apt`.
3. `sudo tee ... > /dev/null` l'écrit dans `/usr/share/keyrings/` (dossier réservé à
   l'administrateur, d'où `sudo`) sans réafficher son contenu.

Vérification de l'empreinte de la clé, demandée par la documentation :

```bash
gpg --no-default-keyring \
--keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
--fingerprint
```

![Téléchargement de la clé GPG et vérification de son empreinte](screenshots/etape4/cle-gpg.png)

**Ce que montre la capture :**

- `HTTP request sent, awaiting response... 200 OK` et `Length: 1725` : la clé (1725 octets)
  a été téléchargée correctement.
- `gpg: directory '/home/aida/.gnupg' created` : première utilisation de `gpg` sur cette
  machine, son dossier de configuration est créé automatiquement.
- `pub rsa4096 2026-09-09 [SC] [expires: 2031-09-08]` : clé RSA de 4096 bits, destinée à la
  signature et à la certification (`SC`), créée le 9 septembre 2026, valable jusqu'au
  8 septembre 2031.
- `D55C 0D1A C78A 8D81 26CB 631C FC9C A96A CA02 6560` : l'**empreinte** de la clé, son
  identifiant unique.
- `uid ... HashiCorp Security (HashiCorp Package Signing)` : le propriétaire de la clé,
  identique à celui que montre la documentation officielle. La mention `[unknown]` signifie
  seulement qu'aucune relation de confiance n'est configurée localement pour cette clé,
  ce qui est normal ici.

#### c) Ajouter le dépôt officiel

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
```

La première commande construit une ligne de dépôt et l'enregistre dans
`/etc/apt/sources.list.d/hashicorp.list`. Ses éléments :

- `arch=$(dpkg --print-architecture)` : l'architecture de la machine (`amd64`) ;
- `signed-by=...hashicorp-archive-keyring.gpg` : `apt` n'accepte de ce dépôt que des
  paquets signés avec la clé vérifiée à l'étape précédente ;
- `https://apt.releases.hashicorp.com` : l'adresse du dépôt HashiCorp ;
- `$(grep ... || lsb_release -cs)` : le nom de code de ma version d'Ubuntu, ici `noble` ;
- `main` : la section du dépôt.

![Ajout du dépôt HashiCorp et mise à jour d'apt](screenshots/etape4/depot-apt.png)

**Ce que montre la capture :** la ligne enregistrée, `deb [arch=amd64 signed-by=...]
https://apt.releases.hashicorp.com noble main`, puis `apt update` qui télécharge pour la
première fois l'index du dépôt HashiCorp (`noble InRelease` et `noble/main amd64
Packages`). `apt` connaît désormais les paquets HashiCorp.

#### d) Installer Terraform et vérifier

```bash
sudo apt-get install terraform
terraform version
```

![Installation de Terraform et vérification de la version](screenshots/etape4/install-terraform.png)

**Ce que montre la capture :**

- `The following NEW packages will be installed: terraform` : un seul paquet est installé.
- `terraform amd64 1.16.3-1 [35.8 MB]` : `apt` télécharge la version **1.16.3** depuis
  `apt.releases.hashicorp.com`, ce qui prouve que l'installation vient bien du dépôt
  officiel. Elle occupe environ 120 Mo sur le disque.
- `Setting up terraform (1.16.3-1)` : l'installation est terminée.
- `terraform version` répond `Terraform v1.16.3 on linux_amd64` : la commande `terraform`
  est utilisable, en version 1.16.3, sur Linux 64 bits.

### 2. Créer la structure du projet

```bash
cd ~/cloud-project
mkdir -p modules/storage modules/database
touch main.tf providers.tf variables.tf locals.tf outputs.tf versions.tf terraform.tfvars
touch modules/storage/{main,variables,outputs}.tf
touch modules/database/{main,variables,outputs}.tf
```

- `mkdir -p` crée les dossiers des deux modules (`-p` crée aussi les dossiers parents et
  ne signale pas d'erreur s'ils existent).
- `touch` crée les fichiers vides. `{main,variables,outputs}` est une expansion de
  l'interpréteur : une seule commande crée les trois fichiers.
- Ces commandes n'affichent rien quand elles réussissent. La vérification se fait avec :

```bash
find . -path ./.git -prune -o -type f -name '*.tf*' -print | sort
```

![Structure du projet Terraform](screenshots/etape4/structure.png)

**Ce que montre la capture :** les **13 fichiers** attendus : 7 à la racine
(`main.tf`, `providers.tf`, `variables.tf`, `locals.tf`, `outputs.tf`, `versions.tf`,
`terraform.tfvars`) et 3 dans chacun des deux modules, `modules/storage/` et
`modules/database/` (`main.tf`, `variables.tf`, `outputs.tf`). `-path ./.git -prune` exclut
le dossier `.git` de la recherche.

Rôle de chaque fichier (Terraform lit tous les fichiers `.tf` d'un dossier comme une seule
configuration ; les noms sont une convention) :

| Fichier | Rôle |
|---|---|
| `main.tf` | Appelle les deux modules |
| `providers.tf` | Configure le provider AWS avec l'endpoint local de Floci |
| `variables.tf` | Déclare les variables (nom, type, description) |
| `terraform.tfvars` | Donne les valeurs des variables, chargé automatiquement |
| `locals.tf` | Valeurs calculées à partir des variables |
| `outputs.tf` | Expose les informations importantes après le déploiement |
| `versions.tf` | Fixe les versions de Terraform et du provider |
| `modules/storage/` | Module du service S3 (`main.tf`, `variables.tf`, `outputs.tf`) |
| `modules/database/` | Module du service DynamoDB (`main.tf`, `variables.tf`, `outputs.tf`) |


---

## Étape 5 : Configuration du provider

Fichiers concernés : [`versions.tf`](versions.tf), [`variables.tf`](variables.tf),
[`terraform.tfvars`](terraform.tfvars), [`providers.tf`](providers.tf).

### 1. `versions.tf` : fixer les versions

Fixe la version minimale de Terraform (`>= 1.5.0`, Terraform installé : v1.16.3) et
indique où télécharger le provider AWS (`hashicorp/aws`, série `~> 5.0`, c'est-à-dire
toute version 5.x mais pas 6.x).

### 2. `variables.tf` et `terraform.tfvars` : variables du provider

Deux variables sont nécessaires pour que le provider sache où envoyer ses requêtes :

| Variable | Valeur (`terraform.tfvars`) | Rôle |
|---|---|---|
| `aws_region` | `us-east-1` | Région des ressources ; région par défaut de Floci |
| `floci_endpoint` | `http://localhost:4566` | Adresse de l'émulateur, identifiée à l'étape 1 |

`variables.tf` **déclare** ces variables (nom, type, description) ; `terraform.tfvars`
leur donne une valeur. Ce dernier est chargé automatiquement par Terraform, sans option
en ligne de commande, car il porte ce nom réservé.

### 3. `providers.tf` : rediriger Terraform vers Floci

Ce fichier configure le provider `aws` pour qu'il envoie ses requêtes à Floci au lieu des
serveurs officiels d'AWS. Trois idées principales :

- **Un bloc `endpoints`**, avec une entrée pour `s3` et une pour `dynamodb`, chacune
  pointant vers `var.floci_endpoint`. C'est ce bloc qui redirige les appels : sans lui,
  Terraform contacterait le vrai AWS. C'est la notion d'**endpoint local**.
- **Des identifiants factices** (`access_key` et `secret_key`) : Floci accepte n'importe
  quelle valeur non vide, ce ne sont pas de vrais secrets.
- **Trois options qui désactivent des vérifications inutiles en local** :
  `skip_credentials_validation` (pas d'appel au service STS), `skip_metadata_api_check`
  (pas de recherche du service de métadonnées, propre aux vraies instances EC2), et
  `skip_requesting_account_id` (pas de récupération de l'identifiant de compte pour
  construire des ARN ; sans impact ici, ni S3 ni DynamoDB n'en ont besoin).

Une quatrième option, `s3_use_path_style`, adresse les buckets en
`http://localhost:4566/bucket` : le style par défaut (`bucket.localhost:4566`) ne
fonctionnerait pas en local.

### 4. Initialiser et valider

```bash
terraform fmt
terraform init
terraform validate
```

![terraform init et terraform validate](screenshots/etape5/init-validate.png)

**Ce que montre la capture :**

- `terraform fmt` ne renvoie rien : les fichiers étaient déjà correctement indentés.
- `terraform init` :
  - `Finding hashicorp/aws versions matching "~> 5.0"...` : Terraform cherche, parmi
    toutes les versions du provider AWS, celles compatibles avec la contrainte fixée
    dans `versions.tf` ;
  - `Installing hashicorp/aws v5.100.0...` puis `Installed ... (signed by HashiCorp)` :
    la version **5.100.0** est retenue et son intégrité est vérifiée par sa signature ;
  - `Terraform has created a lock file .terraform.lock.hcl` : ce fichier enregistre la
    version exacte choisie et ses checksums, pour que `terraform init` fasse toujours le
    même choix par la suite. Il est **versionné** dans ce projet (voir
    [Notes](#notes)), conformément à la recommandation de la documentation Terraform ;
  - `Terraform has been successfully initialized!` : le provider est téléchargé dans
    `.terraform/` (ignoré par Git) et le projet est prêt.
- `terraform validate` répond `Success! The configuration is valid.` : la syntaxe et la
  cohérence de la configuration (types de variables, références) sont correctes.

Ces deux commandes ne contactent pas encore l'émulateur Floci : aucune ressource n'est
définie dans `main.tf` pour l'instant, ce sera fait à l'étape suivante.

### 5. Différence entre le vrai Cloud Provider et Floci

| | Vrai AWS | Floci |
|---|---|---|
| Endpoints | URL officielles d'AWS (par défaut) | `http://localhost:4566`, fixé par le bloc `endpoints` |
| Identifiants | Vraies clés, rôle IAM ou SSO, à protéger | Valeurs factices |
| Vérifications de démarrage | Appel au service STS, au service de métadonnées EC2 | Désactivées (`skip_*`) |
| Adressage S3 | Style virtuel (`bucket.s3.amazonaws.com`) | Path-style (`localhost:4566/bucket`) |
| Compte et coût | Vrai compte AWS, facturation | Aucun compte, gratuit, entièrement local |

**Le code des ressources reste identique** (`aws_s3_bucket`, `aws_dynamodb_table`, écrites
à l'étape suivante) : seul le bloc `provider` change. Il suffirait de retirer le bloc
`endpoints` et les options `skip_*`, et de fournir de vraies clés, pour que la même
configuration vise le véritable AWS.


---

## Étapes 6 à 8 : Variables, `terraform.tfvars` et `locals`

Fichiers concernés : [`variables.tf`](variables.tf), [`terraform.tfvars`](terraform.tfvars),
[`locals.tf`](locals.tf).

### 1. Variables du projet : `variables.tf`

En plus de `aws_region` et `floci_endpoint` (étape 5, configuration du provider),
`variables.tf` déclare deux variables propres au projet :

| Variable | Rôle |
|---|---|
| `project_name` | Nom du projet, utilisé dans le nom des ressources |
| `environment` | Environnement (`dev`, `prod`...) |

Ces deux variables serviront à construire automatiquement le nom des ressources (bucket S3,
table DynamoDB), via le `local` défini plus bas, au lieu de répéter une chaîne de
caractères dans chaque ressource.

### 2. Valeurs des variables : `terraform.tfvars`

```hcl
project_name = "cloud-project"
environment  = "dev"
```

Ce fichier donne une valeur à chaque variable déclarée dans `variables.tf`. Il est chargé
**automatiquement** par Terraform (`terraform plan`, `terraform apply`...), sans option en
ligne de commande, car il porte ce nom réservé.

### 3. Une valeur calculée : `locals.tf`

`locals.tf` définit `resource_prefix`, qui combine les deux variables du projet :

- `variable` est une **entrée** de la configuration : sa valeur vient de l'extérieur
  (ici, de `terraform.tfvars`).
- `local` est une **valeur calculée** à partir d'autres valeurs (variables, autres
  `locals`...) : on ne peut pas lui donner de valeur depuis `terraform.tfvars`, elle est
  toujours dérivée dans le code.

Avec les valeurs ci-dessus, `local.resource_prefix` vaut `"cloud-project-dev"`. Le
calculer une seule fois dans un `local` évite de répéter la même concaténation dans
chaque ressource, et garantit que toutes les ressources du projet utilisent exactement le
même préfixe. Il sera utilisé dans le nom du bucket S3 et de la table DynamoDB, à
l'[étape 9](#étape-9--création-des-modules).

### 4. Valider

```bash
terraform fmt
terraform validate
```

![terraform validate après ajout des variables et des locals](screenshots/etape6-8/validate.png)

**Ce que montre la capture :** `terraform fmt` a reformaté `terraform.tfvars`
(alignement des `=`), et `terraform validate` répond `Success! The configuration is
valid.` La validation réussit même si `project_name`, `environment` et
`resource_prefix` ne sont encore utilisés dans aucune ressource : Terraform accepte des
variables et des `locals` déclarés à l'avance, non encore utilisés. Ils prendront leur
utilité à l'étape suivante.

---

## Étape 9 : Création des modules

Fichiers concernés : [`main.tf`](main.tf), [`modules/storage/`](modules/storage),
[`modules/database/`](modules/database).

### Pourquoi des modules

Un module regroupe les ressources d'un service (ici, une ressource principale chacun) avec
ses propres entrées (`variables.tf`) et sorties (`outputs.tf`). Il sépare la
**configuration générale** du projet (racine) de la **définition de chaque service**
(modules), et permet de réutiliser le même code pour plusieurs instances si besoin, en
changeant simplement les valeurs passées en entrée.

### Module `storage` : Amazon S3

`modules/storage/main.tf` définit une seule ressource, `aws_s3_bucket`, dont le nom vient
d'une variable d'entrée `name` (`modules/storage/variables.tf`). Le module expose ensuite
ce nom via `output "resource_name"` (`modules/storage/outputs.tf`), pour qu'il soit lisible
depuis le reste du projet.

### Module `database` : Amazon DynamoDB

`modules/database/main.tf` définit une ressource `aws_dynamodb_table`, avec :

- `billing_mode = "PAY_PER_REQUEST"` : facturation à l'usage, sans capacité à provisionner
  à l'avance (l'alternative, `PROVISIONED`, demanderait de fixer une capacité de lecture
  et d'écriture fixe) ;
- `hash_key = "id"` : DynamoDB est une base clé-valeur, elle a besoin d'une **clé de
  partition** pour identifier chaque enregistrement ;
- un bloc `attribute` qui déclare le **type** de cet attribut clé (`S` pour *String*) :
  DynamoDB exige de déclarer les attributs utilisés comme clés, mais laisse le reste du
  schéma libre.

Comme pour `storage`, le nom vient d'une variable d'entrée `name`, et le module expose ce
nom via `output "resource_name"`.

### Appeler les deux modules : `main.tf` (racine)

```hcl
module "storage" {
  source = "./modules/storage"

  name = "${local.resource_prefix}-bucket"
}

module "database" {
  source = "./modules/database"

  name = "${local.resource_prefix}-table"
}
```

- `source = "./modules/storage"` : chemin **local** vers le module (les modules peuvent
  aussi venir d'un registre ou d'un dépôt Git, ce n'est pas le cas ici).
- `name = "${local.resource_prefix}-bucket"` : le nom passé au module. C'est ici que tout
  ce qui a été préparé aux étapes précédentes converge : `local.resource_prefix`
  (étape 8) vaut `"cloud-project-dev"` avec les valeurs actuelles de `terraform.tfvars`,
  ce qui donne `cloud-project-dev-bucket` pour le bucket S3 et `cloud-project-dev-table`
  pour la table DynamoDB. **Aucun nom n'est écrit en dur** dans les ressources : changer
  `project_name` ou `environment` dans `terraform.tfvars` renomme tout le projet.

Le sujet donne comme exemple `name = local.resource_prefix` (la même valeur pour les deux
modules), ce qui est valable : S3 et DynamoDB ont chacun leur propre espace de noms, donc
un bucket et une table peuvent porter le même nom sans conflit. J'ai choisi d'ajouter les
suffixes `-bucket` et `-table` pour que chaque ressource ait un nom explicite,
distinguable dans Floci UI et dans les sorties de Terraform (`plan`, `apply`, `outputs`).

### Documentation générée automatiquement : `terraform-docs` 

Chaque module possède un `README.md` généré automatiquement avec
[`terraform-docs`](https://terraform-docs.io/), directement depuis le code
(`variables.tf`, `outputs.tf`, ressources utilisées) :

- [modules/storage/README.md](modules/storage/README.md)
- [modules/database/README.md](modules/database/README.md)

Installation (méthode binaire, documentation officielle) :

```bash
mkdir -p /tmp/terraform-docs-install
curl -Lo /tmp/terraform-docs-install/terraform-docs.tar.gz https://github.com/terraform-docs/terraform-docs/releases/download/v0.24.0/terraform-docs-v0.24.0-$(uname)-amd64.tar.gz
tar -xzf /tmp/terraform-docs-install/terraform-docs.tar.gz -C /tmp/terraform-docs-install
chmod +x /tmp/terraform-docs-install/terraform-docs
sudo mv /tmp/terraform-docs-install/terraform-docs /usr/local/bin/terraform-docs
```

Génération, pour chaque module :

```bash
terraform-docs markdown table --output-file README.md --output-mode inject modules/storage
terraform-docs markdown table --output-file README.md --output-mode inject modules/database
```

`--output-mode inject` insère le contenu généré entre des balises
`<!-- BEGIN_TF_DOCS -->` et `<!-- END_TF_DOCS -->` dans le `README.md` du module. Chaque
fichier généré contient quatre tableaux, construits automatiquement à partir du code :

- **Providers** : le provider utilisé par le module (`aws`) ;
- **Resources** : la ressource principale du module (`aws_s3_bucket.this` ou
  `aws_dynamodb_table.this`), avec un lien direct vers sa documentation officielle sur le
  Registry Terraform ;
- **Inputs** : les variables d'entrée du module (`name`), avec leur type, leur
  description et si elles sont obligatoires, reprises telles qu'écrites dans
  `variables.tf` ;
- **Outputs** : les sorties du module (`resource_name`), reprises depuis `outputs.tf`.

L'intérêt de cette génération automatique, plutôt qu'une documentation écrite à la main :
elle **reste synchronisée avec le code**. Si une variable est ajoutée, renommée ou sa
description modifiée dans `variables.tf`, il suffit de relancer la commande
`terraform-docs` correspondante pour que le README du module reflète exactement l'état
actuel du code, sans risque d'oubli.

### Initialiser et valider

Un nouveau module demande de relancer `terraform init` :

```bash
terraform fmt
terraform init
terraform validate
```

![Initialisation avec les deux modules et validation](screenshots/etape9/init-validate.png)

**Ce que montre la capture :**

- `Initializing modules...` avec `- storage in modules/storage` et
  `- database in modules/database` : Terraform a détecté les deux modules locaux appelés
  depuis `main.tf`.
- `Reusing previous version of hashicorp/aws from the dependency lock file` et
  `Using previously-installed hashicorp/aws v5.100.0` : le provider avait déjà été
  téléchargé à l'étape 5 (et sa version figée dans `.terraform.lock.hcl`), Terraform le
  réutilise sans le retélécharger.
- `Terraform has been successfully initialized!` : le projet, modules compris, est prêt.
- `terraform validate` répond `Success! The configuration is valid.` : la syntaxe des
  modules et de leurs appels est correcte.

Ces commandes ne créent encore aucune ressource dans Floci : ce sera l'objet de
l'[étape 11](#étape-11--validation-et-déploiement), avec `terraform plan` puis
`terraform apply`.
---

## Étape 10 : Outputs

Fichier concerné : [`outputs.tf`](outputs.tf).

### Deux niveaux d'outputs

Chaque module possède déjà son propre `output "resource_name"` (voir
[Étape 9](#étape-9--création-des-modules)) : c'est lui qui expose, depuis l'intérieur du
module, le nom de la ressource créée (`aws_s3_bucket.this.id` ou
`aws_dynamodb_table.this.id`).

Un module est une boîte fermée : ce qu'il calcule en interne n'est visible depuis
l'extérieur **que s'il le déclare via son propre `output`**, et cette valeur reste
elle-même invisible à la racine tant qu'elle n'y est pas **redéclarée**. `outputs.tf`, à
la racine, expose donc à son tour les deux valeurs :

- `storage_name`, qui vaut `module.storage.resource_name` ;
- `database_name`, qui vaut `module.database.resource_name`.

`module.storage.resource_name` va chercher la valeur exposée par le module `storage`
(appelé dans `main.tf` à l'étape 9). Sans cette redéclaration à la racine, le nom du
bucket et celui de la table resteraient calculés en interne, mais ne s'afficheraient
jamais après un déploiement.

### Valider

```bash
terraform fmt
terraform validate
```

![terraform validate après ajout des outputs](screenshots/etape10/validate.png)

**Ce que montre la capture :** `terraform validate` répond `Success! The configuration is
valid.`. La validation vérifie que `module.storage.resource_name` et
`module.database.resource_name` existent bien dans les modules appelés, mais **pas leur
valeur réelle** : les noms concrets (`cloud-project-dev-bucket`,
`cloud-project-dev-table`) ne s'afficheront qu'après un `terraform apply`, à
l'[étape 11](#étape-11--validation-et-déploiement).

Le projet Terraform est désormais complet : provider (étape 5), variables et
`terraform.tfvars` (étapes 6-7), `locals` (étape 8), modules (étape 9) et outputs
(étape 10). Reste le déploiement.

---

## Étape 11 : Validation et déploiement

### 1. Vérifications préalables

```bash
docker ps
terraform init
terraform fmt
terraform validate
```

Le conteneur `floci` doit être `healthy` avant tout déploiement, puisque `apply`
contactera réellement l'émulateur. `init`, `fmt` et `validate` ont déjà été détaillés aux
étapes précédentes ; ils sont relancés ici par sécurité, comme le demande le sujet.

### 2. Prévisualiser : `terraform plan`

```bash
terraform plan
```

![Plan Terraform : deux ressources à créer](screenshots/etape11/plan.png)

**Ce que montre la capture :** `terraform plan` compare le code, l'état connu de
Terraform (encore vide, aucun `apply` n'a été fait) et la réalité côté Floci, sans rien
créer. Chaque ligne précédée de `+` indique une **création** prévue (les autres symboles
possibles sont `~` pour une modification et `-` pour une destruction) :

- `module.database.aws_dynamodb_table.this will be created`, avec
  `name = "cloud-project-dev-table"`, `billing_mode = "PAY_PER_REQUEST"` et
  `hash_key = "id"` ;
- `module.storage.aws_s3_bucket.this will be created`, avec
  `bucket = "cloud-project-dev-bucket"`.

Les deux noms confirment que `local.resource_prefix` (étape 8) et les suffixes
`-bucket`/`-table` (étape 9) fonctionnent comme prévu, sans aucune valeur écrite en dur.
Les champs marqués `(known after apply)` (l'`arn`, l'`id`...) ne peuvent être connus
qu'une fois la ressource réellement créée. Le résumé final,
`Plan: 2 to add, 0 to change, 0 to destroy`, confirme qu'aucune autre action n'est
prévue.

### 3. Déployer : `terraform apply`

```bash
terraform apply
```

Terraform réaffiche le même plan, puis demande une confirmation explicite :

```text
Do you want to perform these actions?
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

Seule la réponse `yes`, en toutes lettres, déclenche la création : c'est la seule étape
du projet qui modifie réellement l'état de Floci.

![Apply Terraform : création des deux ressources](screenshots/etape11/apply.png)

**Ce que montre la capture :**

- Les deux ressources sont créées en parallèle (`Creating...` sur les deux lignes), puis
  confirmées (`Creation complete`) avec leur identifiant réel entre crochets.
- Le temps de création (`0s`) s'explique par l'émulation locale : pas de vrai
  provisionnement matériel ni de latence réseau vers un datacenter.
- `Resources: 2 added, 0 changed, 0 destroyed` correspond exactement au plan annoncé.
- Les deux `outputs` définis à l'étape 10 affichent enfin leur **valeur réelle** :
  `cloud-project-dev-table` et `cloud-project-dev-bucket`. C'est la preuve que la chaîne
  complète `terraform.tfvars` → `variables` → `locals` → `modules` → `outputs`
  fonctionne de bout en bout.

### 4. Vérifier dans Floci UI

Sur <http://localhost:4500>, les deux ressources apparaissent bien.

**Vue d'ensemble** (`/console/aws`) :

![Deux services avec 1 ressource chacun dans Floci UI](screenshots/resources.png)

Les cartes **Storage** et **DynamoDB** affichent chacune **`1 resource`** : exactement le
résultat attendu après un `terraform apply` qui a créé une ressource par module
(`Apply complete! Resources: 2 added`). Les autres services du provider AWS restent à
`0 resources` (à l'exception de *Compute*, qui affiche des ressources de référence de
l'environnement, déjà présentes avant tout déploiement voir
[Étape 2](#étape-2--lancement-de-floci-ui)), ce qui confirme que seules les deux
ressources du projet ont été créées.

**Détail : Storage** (`/cloud-explorer/aws/storage`) :

![Bucket S3 visible dans Floci UI](screenshots/etape11/storage-detail.png)

Le bucket **`cloud-project-dev-bucket`** apparaît, type `bucket`, cloud `aws`, créé le
`2026-09-23T21:06:58.000Z` : un horodatage qui correspond au moment exact du
`terraform apply` ci-dessus.

**Détail : DynamoDB** (`/cloud-explorer/aws/nosql`) :

![Table DynamoDB visible dans Floci UI](screenshots/etape11/dynamodb-detail.png)

La table **`cloud-project-dev-table`** apparaît, statut **`ACTIVE`**, région
`us-east-1`, créée le `2026-09-23T21:06:59.000Z`, une seconde après le bucket, l'ordre
exact observé dans les logs de `terraform apply` (`Creating...` sur les deux ressources
quasi simultanément).

Le nom de chaque ressource, dans l'UI, correspond exactement à celui annoncé par
`terraform plan` et confirmé par les `outputs` de `terraform apply` : la boucle
configuration → déploiement → vérification est complète.


---

## Étape 12 : Destruction

### 1. Prévisualiser : `terraform plan -destroy`

```bash
terraform plan -destroy
```

Même logique que `terraform plan`, mais dans l'autre sens : chaque ligne est précédée de
`-` au lieu de `+`, pour annoncer une **suppression**. Avant toute action, Terraform
affiche `Refreshing state...` pour chaque ressource : il interroge Floci afin de
confirmer qu'elles existent bien telles qu'il les connaît, avant de calculer le plan.

Le résumé, `Plan: 0 to add, 0 to change, 2 to destroy`, annonce la suppression des deux
ressources créées à l'[étape 11](#étape-11--validation-et-déploiement). Le détail de
chaque ressource montre la notation `valeur -> null` : chaque attribut passera de sa
valeur actuelle à « rien », par exemple
`arn = "arn:aws:dynamodb:us-east-1:000000000000:table/cloud-project-dev-table" -> null`
pour la table DynamoDB (le `000000000000` est le compte factice de Floci, déjà repéré à
l'[étape 1](#étape-1--installation-et-lancement-de-floci)).

### 2. Détruire : `terraform destroy`

```bash
terraform destroy
```

Terraform réaffiche le même plan, puis demande une confirmation explicite, distincte de
celle de `apply` :

```text
Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes
```

Seule la réponse `yes`, en toutes lettres, déclenche la suppression. Sur un vrai AWS,
cette action serait irréversible (*"There is no undo"*) et potentiellement coûteuse en
données perdues ; avec Floci, elle est sans risque puisque l'environnement est local et
jetable mais le réflexe de vérifier le plan avant de confirmer reste le même que sur un
vrai projet.


**On obtient :**

```text
module.storage.aws_s3_bucket.this: Destroying... [id=cloud-project-dev-bucket]
module.database.aws_dynamodb_table.this: Destroying... [id=cloud-project-dev-table]
module.storage.aws_s3_bucket.this: Destruction complete after 0s
module.database.aws_dynamodb_table.this: Destruction complete after 0s

Destroy complete! Resources: 2 destroyed.
```

Les deux ressources sont détruites en parallèle (`Destroying...` sur les deux lignes),
puis confirmées (`Destruction complete`). `Resources: 2 destroyed` correspond exactement
au plan annoncé. Les `outputs` `database_name` et `storage_name` repassent eux aussi à
`null`, cohérence logique avec la disparition des ressources qu'ils exposaient.

### 3. Vérifier dans Floci UI

Sur <http://localhost:4500/console/aws>, les cartes **Storage** et **DynamoDB**
affichent maintenant **`0 resources`**, en symétrie exacte avec la vue d'ensemble de
l'étape 11 qui en affichait `1` pour chacune.

![Storage, Database et DynamoDB repassent à 0 ressource après terraform destroy](screenshots/destroy.png)

Les pages détaillées confirment la disparition, avec un message explicite de l'interface :

![Page Storage : No S3 Storage found](screenshots/etape12/storage-empty.png)

Sur `/cloud-explorer/aws/storage` : **`No S3 Storage found.`**,
*« The connected runtime did not return any S3 Storage resources. »*. Le bucket
`cloud-project-dev-bucket`, présent à l'étape 11, n'existe plus.

![Page DynamoDB : No DynamoDB found](screenshots/etape12/dynamodb-empty.png)

Sur `/cloud-explorer/aws/nosql` : **`No DynamoDB found.`**,
*« The connected runtime did not return any DynamoDB resources. »*. La table
`cloud-project-dev-table` n'existe plus non plus.

### 4. Vérification complémentaire : l'état Terraform

```bash
terraform show
```

Sans argument, cette commande affiche l'état actuel connu de Terraform
(`terraform.tfstate`). Après un `destroy` réussi, elle répond
`The state file is empty. No resources are represented.` : Terraform lui-même confirme
qu'il ne gère plus aucune ressource, en cohérence avec ce que montre Floci UI.

---

## Notes

- Le fichier `.terraform.lock.hcl` est **versionné** (il n'est pas dans le `.gitignore`),
  conformément à la documentation Terraform : il garantit les mêmes versions de provider
  pour tous.


## Références

### Floci
- Floci : <https://floci.io/> et <https://github.com/floci-io/floci>
- Floci CLI : <https://github.com/floci-io/floci-cli>
- Floci UI : <https://github.com/floci-io/floci-ui>

### Terraform
- Documentation générale : <https://developer.hashicorp.com/terraform/docs>
- Installation (tutoriel officiel) : <https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli>
- Dependency Lock File : <https://developer.hashicorp.com/terraform/language/files/dependency-lock>
- Provider AWS — ressource `aws_s3_bucket` : <https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket>
- Provider AWS — ressource `aws_dynamodb_table` : <https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table>

### Outils
- terraform-docs : <https://terraform-docs.io/> et <https://github.com/terraform-docs/terraform-docs>