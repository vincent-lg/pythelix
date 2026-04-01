---
title: Premiers pas avec Pythelix
---

Pythelix est un moteur de jeu textuel. Il permet de créer son propre jeu textuel (MUD, ou Multi-User Dungeon). Il se veut flexible et simple d'utilisation.

Cette page ne présuppose aucune connaissance préalable de Pythelix. Vous n'avez rien à faire ni à installer avant de la lire. Si vous n'avez jamais utilisé Pythelix, il peut être utile de suivre les étapes décrites ici une par une. La meilleure façon d'apprendre, c'est de pratiquer.

## Télécharger Pythelix

Pythelix propose des versions binaires pour plus de simplicité : pas besoin d'installer un langage de programmation. Il suffit de télécharger une archive.

<details markdown="1">
<summary>Voir les instructions pour Windows (x64)</summary>

Commencez par [télécharger Pythelix pour Windows x64](https://github.com/vincent-lg/pythelix/releases/download/latest-windows/pythelix-windows.zip) .

Il s'agit d'une simple archive ZIP. Une fois téléchargée, extrayez-la où vous le souhaitez.

L'archive contient plusieurs répertoires, comme `bin`, `lib`, `release`, `worldlets`. Nous y reviendrons plus tard. Pour l'instant, rendez-vous dans `bin`.

Ce répertoire contient plusieurs fichiers pour lancer le jeu. Vous pouvez :

1. Double-cliquer sur le fichier `.bat` (nous verrons lequel). C'est simple, mais l'inconvénient est que vous ne verrez peut-être pas le résultat.
2. Ouvrir une console (recommandé) : dans la barre d'adresse de l'explorateur, tapez `cmd` et appuyez sur ENTRÉE. Cela ouvrira une ligne de commande dans ce dossier. Vous pouvez bien sûr ouvrir la console autrement et naviguer vers le dossier `bin` avec `cd`. Ensuite, lancez les scripts `.bat` en tapant leur nom. C'est préférable car vous verrez le résultat des opérations.

Dans tous les cas :

1. Lancez d'abord `migrate.bat` : ce script effectue les migrations de la base de données. Si vous regardez dans le répertoire parent, vous devriez voir un fichier `pythelix.db`. C'est votre base de données (inutile de l'ouvrir).
2. Lancez ensuite le jeu avec `pythelix.bat`. Le serveur devrait démarrer et plusieurs messages s'afficheront pour confirmer son lancement.

Vous pouvez maintenant ouvrir votre client MUD préféré (zMUD, VIPMud, CocoMUD...) et vous connecter à l'hôte `localhost`, port 4000.

Vous devriez voir le message d'accueil de Pythelix.

Pour arrêter le serveur, retournez dans la console où vous avez lancé `pythelix.bat` et appuyez sur CTRL + C deux fois (voire trois fois sous Windows, selon les cas).

</details>

<details markdown="1">
<summary>Voir les instructions pour Linux (x64)</summary>

Commencez par [télécharger Pythelix pour Linux x64](https://github.com/vincent-lg/pythelix/releases/download/latest-linux/pythelix-linux.tar.gz) .

    wget https://github.com/vincent-lg/pythelix/releases/download/latest-linux/pythelix-linux.tar.gz

Il s'agit d'une simple archive TAR. Une fois téléchargée, extrayez-la où vous le souhaitez.

    tar -xzf pythelix-linux.tar.gz

L'archive contient plusieurs répertoires, comme `bin`, `lib`, `release`, `worldlets`. Nous y reviendrons plus tard. Pour l'instant, rendez-vous dans `bin`.

    cd bin

Ce répertoire contient plusieurs fichiers pour lancer le jeu.

1. Lancez d'abord `./migrate` : ce script effectue les migrations de la base de données. Si vous regardez dans le répertoire parent, vous devriez voir un fichier `pythelix.db`. C'est votre base de données (inutile de l'ouvrir).
2. Lancez ensuite le jeu avec `./pythelix`. Le serveur devrait démarrer et plusieurs messages s'afficheront pour confirmer son lancement.

Vous pouvez maintenant ouvrir votre client MUD préféré (Telnet, TinTin++...) et vous connecter à l'hôte `localhost`, port 4000.

    telnet localhost 4000

Vous devriez voir le message d'accueil de Pythelix.

Pour arrêter le serveur, retournez dans la console où vous avez lancé `./pythelix` et appuyez sur CTRL + C deux fois.

</details>

<details markdown="1">
<summary>Voir les instructions pour les autres plateformes</summary>

Si vous n'utilisez pas une version x64 de Windows ou Linux, il vous faudra installer Pythelix depuis les sources. Ce n'est pas compliqué mais vous devrez [installer Elixir](https://elixir-lang.org/install.html) sur votre système. Choisissez une version récente d'Elixir et d'OTP.

Pour télécharger le code, vous pouvez utiliser Git :

    git clone https://github.com/vincent-lg/pythelix.git

Puis rendez-vous dans le répertoire et exécutez les commandes habituelles pour un projet Elixir :

    cd pythelix
    mix deps.get
    mix ecto.create
    mix ecto.migrate

Enfin, lancez le serveur :

    ./dev

Sous Windows, il existe aussi `dev.bat`.

Le serveur démarrera. Vous pourrez connecter votre client MUD à `localhost` sur le port 4000.

Si vous souhaitez ouvrir IEX pour déboguer, utilisez `./devex` ou `devex.bat`.

</details>

## Première connexion

La première étape est de se connecter à Pythelix. Utilisez votre client MUD préféré, indiquez `localhost` comme nom d'hôte et `4000` comme port. Pythelix doit être en cours d'exécution (voir les sections précédentes).

Une fois connecté à Pythelix, dans votre client MUD, vous devriez voir quelque chose comme :

```
  ____        _   _          _ _
 |  _ \ _   _| |_| |__   ___| (_)_  __
 | |_) | | | | __| '_ \ / _ \ | \ \/ /
 |  __/| |_| | |_| | | |  __/ | |>  <
 |_|    \__, |\__|_| |_|\___|_|_/_/\_\
        |___/
        Welcome to the Pythelix Engine
-------------------------------------------------------------------------------
Enter your username or 'new' to create a new one.
```

Pythelix vous accueille avec un peu d'art ASCII. Ce n'est pas très joli et peut bien sûr être modifié pour coller à votre jeu. Mais avant de se lancer dans la construction, nous avons besoin d'un compte. Créons-en un. Tapez `new` dans votre client MUD :

    > new

    Welcome, new user! Enter your new username.

Vous pouvez créer un compte avec le nom de votre choix. Pour cet exemple, nous utiliserons le nom `admin`, mais ce n'est absolument pas obligatoire :

    > admin

    Enter your new account's password.

Choisissez un mot de passe (plus il est long, mieux c'est).

    > MonMotDePasse

    Enter your username or 'new' to create a new one.

Ceci est évidemment un exemple.

Nous voici de retour à l'écran de connexion initial.

Tapez `admin` (notre nom d'utilisateur) :

    > admin

    Enter the password for this account.

Nous avions choisi `MonMotDePasse` comme mot de passe, entrons-le :

    > MonMotDePasse

    Welcome back!
    Une boulangerie
       Le parfum chaleureux du pain tout juste sorti du four et des
    pâtisseries sucrées envahit l'air dès l'entrée de cette petite
    boutique accueillante. Une fine couche de farine recouvre les
    planches en bois du sol et les comptoirs. Les étagères et vitrines
    regorgent de produits dorés : miches de pain croustillant, pâtisseries
    délicates et confiseries de toutes formes et de toutes tailles. Le
    glaçage brille sous un éclairage tamisé, tandis que noix, fruits
    rouges et pépites de chocolat ornent nombre de ces douceurs avec une
    précision artistique.
       Au fond de la boutique, une caisse enregistreuse ancienne en bois
    trône sur un comptoir, ses ornements en laiton légèrement ternis par
    le temps et l'usage.

Vous avez créé votre premier compte. Et comme c'est le premier, Pythelix lui accorde les privilèges d'administrateur. N'attendez cependant pas trop de commandes d'administration : dans Pythelix, la majorité de la construction se fait en dehors du client MUD.

## Administration, premier aperçu des concepts de Pythelix

Voyons d'abord les commandes auxquelles nous avons accès en tant qu'administrateur :

```
> help
General
  drop           get            look           quit
Information
  help
Administrator
  apply          pythello       spawn          system
```

Le résultat peut bien sûr être différent. Le point important est que... il n'y a pas beaucoup de commandes. Surtout en administration. Nous en avons trois :

- apply : applique les worldlets (nous verrons plus bas ce que cela signifie) ;
- pythello : exécuter du code Pythello ;
- system : afficher des informations système.

Vous pouvez lancer la commande system. Elle fournit des détails assez techniques sur le système Pythelix en cours d'exécution. Ces informations peuvent s'avérer utiles pour déboguer ou s'assurer que le serveur ne croule pas sous la charge des joueurs.

Mais la plus importante, bien entendu, c'est la commande pythello.

Pythelix dispose de son propre langage de script, appelé Pythello. Il ressemble beaucoup à Python, mais n'est pas tout à fait identique : Pythello est conçu pour le scripting de jeu, avec une prise en charge native des entités, des références et de fonctionnalités propres au jeu. Si vous ne connaissez pas la syntaxe Python, pas d'inquiétude : nous expliquerons tout par des exemples, ce qui est souvent la meilleure façon d'apprendre.

Pour commencer : vous devez taper la commande pythello (vous pouvez l'écrire `py`) suivie d'un peu de code. Quelque chose de très simple pour le premier test :

```
> py 35 * 4
140
```

Extrêmement impressionnant, je sais. Vous avez entré du code Pythello (`35 * 4`) et le moteur a répondu 140.

Bien sûr, Pythello permet de faire bien des choses, mais le principe reste le même : on tape la commande avec du code et on voit le résultat en réponse.

### Les entités

Pythelix repose sur deux concepts importants : le premier est celui des [entités](../entities.md).

Une entité dans Pythelix est un élément du monde ou du gameplay. Une salle est une entité. Un PNJ est une entité. Un personnage est une entité. Et c'est aussi le cas de choses plus surprenantes, comme les menus, les commandes... et même les clients (les connexions individuelles). Si vous connaissez LambdaMOO, vous pouvez voir les entités comme des objets : leur comportement est sensiblement le même, bien que le terme "entité" ait été choisi pour éviter toute confusion.

Cela peut paraître un peu abstrait, alors passons à la pratique. Dans votre client MUD, tapez :

```
> py self
Entity(id=13)
```

`self` est simplement une variable contenant notre joueur (celui qui appelle `py`). Dans cet exemple, `self` est l'entité d'ID 13. Les ID sont des nombres uniques (deux entités ne peuvent pas avoir le même ID). Ici, notre joueur est l'entité d'ID 13 (ce nombre peut être très différent chez vous).

Voyons un autre exemple : j'ai dit que les salles sont aussi des entités. Regardons donc la salle où se trouve le joueur :

```
> py location
!room/bakery!
```

`location` est une autre variable toujours accessible dans la commande `pythello`. Elle contient la position du joueur (dans ce cas, la salle).

Le résultat est un peu différent : nous ne voyons pas l'ID, mais quelque chose entre points d'exclamation. Ce quelque chose est la clé de l'entité. Une entité peut avoir une clé (une chaîne de caractères unique, contenant des lettres et d'autres caractères). Ici, la position a pour clé `room/bakery`.

> Pourquoi est-il utile d'avoir à la fois des ID et des clés ?

Comme nous le verrons plus tard, certaines entités n'ont pas d'ID. Seulement une clé. Et les entités ont besoin d'une clé quand elles sont créées par le système de construction (nous verrons pourquoi sous peu).

L'essentiel à retenir :

- Les entités peuvent avoir un ID (un nombre).
- Les entités peuvent avoir une clé (une chaîne de lettres ou d'autres caractères).
- Les ID et les clés sont uniques (deux entités ne peuvent pas avoir le même ID ni la même clé).

> Les entités peuvent-elles avoir à la fois un ID et une clé ?

Oui. Notre position affiche sa clé, mais elle possède aussi un ID :

```
> py location.id
3
```

On accède aux attributs avec la syntaxe `entité.NOM_ATTRIBUT`. `id` est un attribut spécial présent sur toutes les entités : il contient l'ID de l'entité. Dans notre exemple, la salle a pour clé `room/bakery` et pour ID 3. Il n'est donc pas impossible (ni même rare) qu'une entité possède les deux.

Examinons ce concept de plus près avec les worldlets.

### Les worldlets

Un worldlet est simplement un fichier (un fichier texte). Il spécifie les entités qui doivent toujours être présentes. Vous ne vous êtes peut-être pas demandé d'où venait l'entité `room/bakery` : la réponse est d'un worldlet.

Plus précisément : ouvrez le répertoire `worldlets`.

<details markdown="1">
<summary>Je ne trouve pas le répertoire "worldlets", où est-il ?</summary>

Si vous avez téléchargé une archive (un fichier .tar.gz ou .zip), le répertoire `worldlets` devrait se trouver juste à l'intérieur, à côté du répertoire `bin`.

Si vous exécutez Pythelix depuis les sources, le dossier `worldlets` se trouve à la racine du projet, comme `lib` ou `assets`.
</details>

À l'intérieur du répertoire, vous devriez trouver plusieurs fichiers texte. Vous pouvez ouvrir n'importe lequel. Mais pour l'instant, ouvrons `room.txt`. En haut, vous devriez voir notre boulangerie :

```
!room/bakery!
parent = "generic/room"
title = "Une boulangerie"
description = Description("""
Le parfum chaleureux du pain tout juste sorti du four et des pâtisseries
sucrées envahit l'air dès l'entrée de cette petite boutique accueillante.
Une fine couche de farine recouvre les planches en bois du sol et les
comptoirs. Les étagères et vitrines regorgent de produits dorés : miches
de pain croustillant, pâtisseries délicates et confiseries de toutes formes
et de toutes tailles. Le glaçage brille sous un éclairage tamisé, tandis
que noix, fruits rouges et pépites de chocolat ornent nombre de ces
douceurs avec une précision artistique.

Au fond de la boutique, une caisse enregistreuse ancienne en bois trône
sur un comptoir, ses ornements en laiton légèrement ternis par le temps
et l'usage.
""")
```

Vous reconnaissez sans doute notre entité. C'est un plan, un schéma : quand Pythelix démarre, il lit tous les worldlets du répertoire et les crée en jeu ou les met à jour (s'ils existent déjà). Ce n'est donc pas l'endroit où l'entité est stockée : c'est simplement ce qui a permis de créer l'entité au départ.

La première ligne, `!room/bakery!`, indique la clé de l'entité. Toutes les entités dans un worldlet ont besoin d'une clé.

Les lignes suivantes définissent des attributs de cette entité : `parent`, `title`, `description`. Leur définition est très proche de la façon dont on crée une variable.

Ne nous soucions pas de `parent` pour l'instant. Regardons d'abord `title`. Comme vous pouvez le deviner, c'est le titre de la salle. On peut y accéder de la même manière, depuis Pythello :

```
> py location.title
"Une boulangerie"
```

Le client répond avec un titre (entouré de guillemets pour indiquer qu'il s'agit d'une chaîne de caractères). Les attributs peuvent être de différents types. Ici, c'est une chaîne. Ce peut être un nombre ou tout autre chose, comme une liste ou un dictionnaire.

Notez un point important : le worldlet ne définit pas l'ID. Il définit seulement la clé. Quand l'entité est créée pour la première fois en jeu, elle peut obtenir un ID qui ne changera jamais tant que l'entité existe.

L'essentiel à retenir : toutes les entités définies dans les worldlets doivent avoir une clé. Elle doit toujours être unique (une clé par entité). Il est impossible de définir une entité sans clé à l'intérieur d'un worldlet.

> Mais alors... cela signifie que notre joueur n'était dans aucun worldlet ?

Non, les worldlets ne définissent pas tout. Il n'aurait pas de sens de stocker les joueurs dans des worldlets par exemple : un joueur est créé en jeu. Il n'a pas de clé, seulement un ID.

> Mais alors, à quoi servent les clés ?

Vous avez remarqué une coquille dans la description de la boulangerie. Ou vous voulez simplement la modifier. Dans Pythelix, la meilleure façon de le faire est de modifier le fichier worldlet (room.txt). Puis, soit redémarrer le jeu, soit appliquer le worldlet. Que se passe-t-il alors ? Pythelix parcourt la liste des worldlets, voit une salle avec la clé `room/bakery`, se dit "tiens, je connais celle-là, elle a été enregistrée sous l'ID 3, voyons si quelque chose a changé", constate que la description a bien changé et met à jour l'entité d'ID 3 en jeu. Il ne la recrée pas puisqu'une entité avec cette clé existe déjà.

Pour illustrer, modifions le titre de l'entité. Dans `worldlets/room.txt`, modifiez cette ligne :

    title = "Une boulangerie"

Remplacez-la par :

    title = "Une boulangerie lumineuse"

Sauvegardez le fichier. Rien ne devrait se passer. Depuis votre client MUD, si vous interrogez l'attribut title :

```
> py location.title
"Une boulangerie"
```

... c'est l'ancienne valeur. Maintenant, appliquons. Depuis le client MUD, vous pouvez appeler la commande `apply` :

```
> apply
Worldlet applied from ...\\pythelix\\worldlets: 34 entities were added or updated.
> py location.title
"Une boulangerie lumineuse"
```

L'entité a été mise à jour. Vous pouvez interroger son ID et constater qu'il est toujours le même :

```
> py location.id
3
```

Nous avons donc la même salle (même entité avec la même clé et le même ID). Elle a été mise à jour par le worldlet.

Retenez bien : un fichier worldlet n'est qu'un schéma d'entités. Ce n'est pas un espace de stockage. Vous y définissez des entités qui seront créées ou mises à jour selon qu'une entité avec la clé donnée existe déjà en jeu ou non.

C'est aussi la raison pour laquelle deux entités ne peuvent pas avoir la même clé : le worldlet utilisant des clés uniques, il se retrouverait à mettre à jour une entité qui possède la même clé. Gardez donc des clés uniques, une par entité. Par défaut, nous utilisons la convention d'écrire une clé sous la forme `<type d'entité>/<identifiant de l'entité>`. Rien ne vous empêche de suivre un système complètement différent, tant que les clés restent uniques.

### Modifier les entités depuis le jeu

Comme nous l'avons vu, il est assez simple de modifier les entités dans les worldlets : il suffit de modifier le fichier texte, de le sauvegarder et d'exécuter la commande `apply`.

Mais vous vous demandez peut-être : est-il possible de modifier l'entité depuis le jeu, avec la commande `py` ?

La réponse est oui : mais soyez extrêmement prudent. Si nous modifions le titre depuis le jeu (en tapant quelque chose comme ceci) :

```
> py location.title = "un nouveau titre"
```

Alors la modification fonctionnera (vous pouvez taper `look` pour vérifier).

Mais que se passe-t-il la prochaine fois que le worldlet est appliqué ?

Eh bien, il verra une entité avec la clé `room/bakery`, mais un titre différent, et il le mettra à jour. Autrement dit, le worldlet prendra toujours le dessus sur l'entité.

Il est donc préférable de faire toute modification dans le worldlet. Tant, bien sûr, que l'entité s'y trouve. Comme dit plus haut, toutes les entités ne sont pas dans les worldlets : les joueurs, les comptes et les clients eux-mêmes ne sont jamais stockés dans des worldlets.

### L'héritage

Vous avez peut-être remarqué l'attribut `parent` dans le worldlet de la boulangerie :

    parent = "generic/room"

Cela indique à Pythelix que notre boulangerie *hérite* de l'entité ayant pour clé `generic/room`. En pratique, cela signifie que la boulangerie obtient automatiquement tous les attributs et méthodes définis sur `generic/room`, sauf si elle les redéfinit avec ses propres valeurs.

La chaîne peut aller plus loin : un parent peut lui-même avoir un parent. Les attributs et méthodes sont recherchés le long de cette chaîne : Pythelix vérifie d'abord l'entité, puis son parent, puis le parent du parent, et ainsi de suite, jusqu'à trouver une correspondance.

Vous pouvez le voir à l'œuvre avec les commandes. Ouvrez `worldlets/command.txt`. Près du début, vous trouverez :

```
!generic/char_command!
parent = "generic/command"
```

Cette entité est une "commande générique de personnage" : un parent pour toutes les commandes accessibles aux personnages. Elle hérite de `generic/command` (une entité encore plus basique). Plus loin, vous verrez :

```
!command/look!
parent = "generic/char_command"
name = "look"
aliases = ["l"]
category = "General"
```

La commande `look` hérite de `generic/char_command`, qui elle-même hérite de `generic/command`. Cela fait trois niveaux d'héritage. La commande `look` n'a pas besoin de tout redéfinir : elle ne précise que ce qui lui est propre (son nom, ses alias, sa catégorie) et hérite du reste.

> Une entité peut-elle avoir plusieurs parents ?

Non. Chaque entité a au plus un parent. C'est un choix de conception délibéré pour garder les choses simples et prévisibles.

### Les méthodes

Jusqu'ici, nous n'avons examiné que les attributs (des données stockées sur les entités). Mais les entités peuvent aussi avoir des *méthodes*, qui définissent leur comportement.

Créons une commande amusante pour voir les méthodes en action. Nous allons ajouter une commande `roll` qui lance un dé avec un résultat aléatoire. Ouvrez `worldlets/command.txt` et ajoutez ce qui suit à la fin du fichier :

```
!command/roll!
parent = "generic/char_command"
name = "roll"
category = "General"

def run(character):
    result = random.randint(1, 6)
    if result == 1:
        character.msg("Vous lancez le dé... 1. Aïe. Les dieux du hasard ne sont pas avec vous aujourd'hui.")
    elif result == 6:
        character.msg("Vous lancez le dé et obtenez un 6 ! Coup critique ! Vous vous sentez invincible.")
    else:
        character.msg(f"Vous lancez le dé et obtenez un {result}. Pas mal, sans plus.")
    endif
```

Décortiquons tout cela :

- `!command/roll!` est la clé de l'entité.
- `parent = "generic/char_command"` signifie que cette commande hérite de la commande générique de personnage, donc tout personnage peut l'utiliser.
- `name = "roll"` est le nom de la commande que les joueurs taperont.
- `category = "General"` détermine où elle apparaît dans la sortie de `help`.

Vient ensuite la méthode :

- `def run(character):` définit une méthode appelée `run`. C'est la méthode que Pythelix appelle quand un joueur tape la commande. Elle reçoit `character`, le joueur qui l'a tapée.
- `random.randint(1, 6)` choisit un nombre aléatoire entre 1 et 6.
- `character.msg(...)` envoie un message au joueur.
- `if`, `elif`, `else`, `endif` fonctionnent comme en Python (sauf `endif` qui ferme le bloc, car Pythello n'utilise pas l'indentation pour délimiter les blocs).

Sauvegardez le fichier et appliquez le worldlet :

```
> apply
```

Vous pouvez maintenant tester votre nouvelle commande :

```
> roll
Vous lancez le dé et obtenez un 4. Pas mal, sans plus.
> roll
Vous lancez le dé et obtenez un 6 ! Coup critique ! Vous vous sentez invincible.
```

Essayez plusieurs fois : vous obtiendrez des résultats différents à chaque fois. Vous devriez aussi voir la commande `roll` en tapant `help`.

Voilà le schéma général pour ajouter du comportement dans Pythelix : définir une entité dans un worldlet, y ajouter des méthodes, appliquer et tester. Les méthodes sont héritées tout comme les attributs : si vous définissez un parent de commande avec un comportement partagé, toutes les commandes filles en bénéficient automatiquement. Il suffit de redéfinir ce qui doit être différent.

Pour en savoir plus sur les méthodes (arguments, annotations de type, types de retour, valeurs par défaut), consultez la [documentation des méthodes](../methods.md).

## Et maintenant ?

Vous avez appris comment lancer le serveur Pythelix. Vous savez comment créer ou modifier des entités (salles et commandes en particulier), avec leurs attributs et méthodes. La bonne nouvelle : vous retrouverez systématiquement ces concepts dans les fonctionnalités de Pythelix.

Vous avez donc assez d'information pour choisir un sujet qui vous intéresse en particulier. Chacun de ces sujets part du principe que vous avez lu ce tutoriel, donc la compréhension des entités, worldlets, attributs, méthodes et héritage est très importante.

Il existe trois types de documentation disponibles :

- À propos : en apprendre plus sur un sujet précis ;
- Pourquoi : expliquer pourquoi une fonctionnalité a été implémentée de cette façon dans les worldlets d'origine ;
- Comment : comment implémenter une fonctionnalité précise.

### À propos

Lisez les tutoriels qui suivent, dans l'ordre que vous voulez :

- [Tout savoir sur les commandes](./commands.md) : apprendre à ajouter des commandes et gérer les cas les plus fréquents (gestion des paramètres, mise en pause...) ;
- [Obtenir plus de détails sur les entités](./entitiess.md) : une explication plus détaillée incluant des concepts moins souvent utilisés (entités partielles, sous-entités...) ;
- [En apprendre plus sur les worldlets](./worldlets.md) : une explication plus détaillée des worldlets ;
- [Comprendre les méthodes et les appels de méthodes imbriqués](/methods.md) : des exemples concrets pour mieux comprendre les méthodes et la façon dont elles sont utilisées ;
- [Ajouter des messages qui varient en fonction de qui les voit](./names.md) : apprendre à créer des noms d'entités (comme des noms de joueur) qui varient en fonction de celui qui les voit ;
- [Comprendre les menus](./menus.md) : comment étendre ou modifier le menu de connexion (ou de futurs menus en jeu) ;
- [Correspondance par match et search](./match.md): apprendre à trouver des entités dans le monde entier ou dans une salle spécifique en fonction de son nom ;
- [Utiliser les modes de jeu pour mettre en place des environnements de jeu parallèles](./modes.md) : apprendre à utiliser les modes de jeu afin d'avoir plusieurs menus ouverts simultanément pour un joueur (généralement un bâtisseur) ;
- [Manipuler le temps réel et le temps de jeu](./time.md) : apprendre à manipuler le temps réel et un temps spécifique au jeu ;
- [Utiliser les entités empilables pour les pièces, billets ou ressources de crafting](./stackables.md) : apprendre à utiliser les entités empilables (stackables) pour représenter un nombre d'entités très important (entités non uniques), très utile pour gérer l'argent ;
- [Les chaînes de caractères aléatoirement générées](./rangen.md) : apprendre à utiliser un générateur de chaîne de caractères aléatoires mais uniques (utile pour créer des numéros de téléphone, plaques d'immatriculation, numéro de sécurité sociale...) ;
- [Gérer les mots de passe de façon simples](./password.md) : apprendre à gérer les mots de passe de façon simples pour ne pas les stocker tel quel dans les entités ;
- [Comprendre comment fonctionne les clients et contrôleurs](./controls.md) : comprendre les clients et le lient entre clients et autres entités (comme des joueurs) ;

### Pourquoi

Les documents dans cette section expliquent pourquoi une fonctionnalité a été implémentée de cette façon et décrivent le worldlet par défaut.

### Comment

Les documents dans cette section se concentrent sur une question : comment implémenter telle ou telle fonctionnalité.

- [Créer, changer et supprimer le prompt](./prompt.md) : apprendre à personnaliser le prompt (la ligne présente sous chaque message) ;
- [Gérer l'encodage pour un client](./encoding.md) : apprendre à utiliser la notion d'encodage pour afficher les caractères accentués différemment pour tous ou un client.
