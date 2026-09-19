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
  Ubuntu
- **Docker Desktop** avec l'intégration WSL activée 

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

**Conclusion :** les quatre vérifications concordent. Floci (AWS) est installé, démarré
dans le conteneur `floci`, joignable sur le port **4566**, et ses services sont
opérationnels.


---

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
