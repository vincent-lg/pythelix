---
title: Les commandes dans Pythelix
---

Créer des commandes dans Pythelix est très simple. Et il est encore plus facile de garder une trace des commandes disponibles et de fournir un système d'aide complet qui ne laisse rien de côté.

## Prérequis

Cette documentation suppose que vous avez lu la [documentation de démarrage](./start.md).

## Les commandes sont des entités

Dans Pythelix, la plupart des choses sont des [entités](./entities.md), et les commandes ne font pas exception. Ce sont des **entités partielles**, ce qui signifie qu'elles ne sont pas stockées en base de données.

Les entités partielles sont créées lors de l'application d'un [worldlet](./worldlets.md) comme d'habitude, mais elles ne seront pas stockées. Si vous souhaitez supprimer une commande, il suffit de la retirer du worldlet et de le réappliquer.

Vous pourriez créer une commande dans Pythelix en écrivant quelque chose comme ceci dans un fichier worldlet :

```
!command/shout!
parent = "generic/char_command"
name = "crier"

def run(character):
    client.msg("PAS SI FORT !")
```

1. Comme toute entité, une commande doit avoir une clé unique. Sa valeur exacte importe peu, mais elle doit être unique.
2. L'attribut `parent` est essentiel ici : cette entité hérite de `"generic/char_command"`. L'entité virtuelle `"generic/char_command"` est le parent de toutes les commandes de personnage.
3. L'attribut `name` contient le nom de la commande, une chaîne de caractères que les joueurs taperont pour invoquer cette commande.
4. La commande définit une seule méthode, `run`, qui est appelée chaque fois que la commande est utilisée par un joueur.

Si un joueur se connecte à votre MUD et tape `crier` ou `crier quelque chose`, il recevra le message :

> PAS SI FORT !

Bien sûr, les commandes peuvent être bien plus puissantes que cela (et le sont généralement), mais il est important de relier ces concepts :

- Vous créez une entité partielle dont le parent est `"generic/char_command"` ou similaire (voir ci-dessous).
- Quand un joueur tape le nom de la commande (ou une abréviation valide de celui-ci), suivi éventuellement d'un espace et d'arguments, la méthode `run` de la commande est exécutée.
- Vous pouvez utiliser toute la puissance de Pythello, le [langage de script](./scripting.md), pour faire en sorte que la commande se comporte comme vous le souhaitez.

Passons maintenant aux détails.

## Parents de commande

En réalité, Pythelix crée automatiquement une (et une seule) entité de commande : `"generic/command"`. Toutes les commandes doivent hériter (directement ou non) de celle-ci.

> Alors, pourquoi avons-nous utilisé `"generic/char_command"` ?

Dans votre worldlet par défaut, vous disposez de quelques sous-types de commandes. Si vous ouvrez le fichier "worldlets/command/generic.txt", tout en haut, vous devriez voir :

```
!generic/char_command!
parent = "generic/command"

!generic/player_command!
parent = "generic/command"

def can_run(self, character):
    return "player" in character.permissions

!generic/admin_command!
parent = "generic/command"

def can_run(self, character):
    return "admin" in character.permissions
```

Vous avez trois nouvelles entités :

- `"generic/char_command"` : toutes les commandes exécutées par un personnage (y compris un personnage joueur ou un PNJ, Personnage Non-Joueur) ;
- `"generic/player_command"` : toutes les commandes accessibles uniquement aux joueurs (pas aux PNJ). Exemple : la commande "quit" (il serait absurde qu'un PNJ quitte le jeu) ;
- `"generic/admin_command"` : les commandes réservées aux administrateurs, inaccessibles aux joueurs ordinaires.

Nous avons donc trois autres entités. Et la plupart des commandes utilisent l'une d'entre elles comme parent. Comme leur propre parent est `"generic/command"`, ce sont toujours des commandes.

> Si j'utilise `"generic/admin_command"` comme parent d'une commande, elle ne sera accessible à aucun joueur... mais pourquoi avoir `"generic/char_command"` et ne pas utiliser directement `"generic/command"` pour toutes les autres commandes ?

Les commandes ne s'exécutent pas uniquement dans le jeu après qu'un personnage s'est connecté. Elles peuvent aussi s'exécuter sur des clients nus (pendant la connexion). Par exemple, quand vous vous connectez au MUD et tapez `"new"` pour créer un nouvel utilisateur, c'est une commande — mais aucun personnage n'existe encore, donc la commande s'exécute sur le client (la connexion) plutôt que sur un personnage. Pour maintenir cette distinction, on utilise `"generic/char_command"` pour les commandes qui nécessitent un personnage et `"generic/command"` pour celles qui n'en ont pas besoin. Toutes les commandes de personnage supposent qu'un personnage les exécute (après connexion). Une commande générique ne fait aucune supposition et est généralement préférée pour les commandes exécutées par des clients.

> Pourquoi Pythelix ne crée-t-il pas ces entités automatiquement ?

Pythelix fait le moins d'hypothèses possible sur votre jeu. Peut-être souhaitez-vous un système de permissions complètement différent. Peut-être ne voulez-vous même pas de personnages. Peut-être voulez-vous que les commandes soient exécutées par des véhicules et que le jeu se connecte à ceux-ci. Seul `"generic/command"` est donc réellement défini par Pythelix. Le reste peut être modifié comme bon vous semble.

Remarquez aussi que nous ne définissons pas seulement trois entités — deux d'entre elles redéfinissent également la méthode `can_run`. Cette méthode vérifie que le personnage peut bien exécuter la commande. On vérifie `character.permissions`, qui est défini sur tous les personnages. Vous pouvez le constater dans `worldlets/character.txt`.

## Attributs de commande

| Attribut       | Type               | Description |
| -------------- | ------------------ | ----------- |
| `parent`       | String             | L'entité parente de la commande. Toujours `"generic/command"` ou une autre entité qui en hérite. |
| `name`         | String             | Le nom de la commande. **Obligatoire**. |
| `can_shorten`  | Boolean            | Vaut `True` par défaut. Si `True`, les formes abrégées du nom de la commande sont acceptées. Par exemple, si la commande s'appelle `shout`, taper `shou` ou même `sh` correspondra à la commande. Souvent souhaitable, mais peut être désactivé pour des commandes individuelles ou des groupes (voir ci-dessous). |
| `syntax`       | String             | La syntaxe décrivant les arguments de la commande. Par défaut, une commande n'a pas d'arguments. Voir la section dédiée ci-dessous. |
| `aliases`      | Liste de strings   | Liste optionnelle de noms alternatifs pour la commande. Exemple : `aliases = ["st", "stat"]` pour atteindre une commande `status`. Notez que puisque les noms de commande peuvent généralement être abrégés, les alias sont moins souvent nécessaires. |

`"char_command"` fournit également les attributs `category` (le nom de la catégorie de la commande) et `help` (le texte d'aide de la commande), mais ceux-ci dépendent en réalité de la manière dont vous configurez votre jeu. Vous pourriez vouloir un système d'aide différent. Ce n'est qu'une valeur par défaut.

> **Astuce :** Vous souhaitez désactiver les abréviations de commande globalement sans répéter `can_shorten = False` dans chaque commande ? C'est simple. Vous pouvez ajouter l'attribut au `"generic/char_command"` dans votre fichier worldlet. Par exemple, modifiez dans votre `worldlets/command/generic.txt` l'entrée `"generic/char_command"` :

```
!generic/char_command!
parent = "generic/command"
can_shorten = False
```

> Pourquoi est-ce que ça fonctionne ?

Les attributs comme `can_shorten` sont recherchés de manière hiérarchique : s'ils ne sont pas définis sur l'entité de commande individuelle, leur valeur est héritée du parent. En définissant `can_shorten = False` sur l'entité parente, toutes les commandes enfants adopteront cette valeur par défaut, à moins qu'elles ne la redéfinissent individuellement.

## Méthodes de commande

Une commande peut définir des méthodes. Nous avons déjà vu que `run` est appelée chaque fois que la commande est exécutée par un joueur. En réalité, il existe plusieurs méthodes disponibles :

| Méthode          | Arguments                   | Usage                                                |
| ---------------- | --------------------------- | ---------------------------------------------------- |
| `refine`         | Spécifiques à la syntaxe    | Peut être utilisée pour modifier programmatiquement les arguments de la syntaxe avant l'appel à `run`. |
| `run`            | Spécifiques à la syntaxe    | Exécutée quand la commande est appelée par un joueur, après que ses arguments ont été raffinés. **Obligatoire.** |
| `refine_error`   | Les arguments sous forme de chaîne | Appelée si `refine` ne peut pas aboutir ou rencontre une erreur. |
| `parse_error`    | Les arguments sous forme de chaîne | Appelée quand l'analyse des arguments de la commande échoue pour une raison quelconque. |

À l'exception de `run`, ces méthodes sont optionnelles. Nous allons maintenant aborder les concepts de syntaxe, d'analyse des arguments et de raffinement.

## Syntaxe et analyse des arguments

Les commandes peuvent accepter des arguments, généralement écrits après le nom de la commande (ou l'un de ses alias), séparés par des espaces. Par exemple, si le joueur tape :

> crier J'ai réussi !

Le texte après `crier` (`J'ai réussi !`) devient les arguments de la commande. Comme expliqué plus haut, `crier` peut être abrégé par défaut, donc `cr J'ai réussi !` fonctionne de manière identique.

Pythelix vous permet de définir une syntaxe simple mais puissante sur chaque commande via l'attribut `syntax`. Par défaut, cet attribut est vide, ce qui signifie que la commande ne prend pas d'arguments.

Vous pouvez spécifier une chaîne de syntaxe suivant un mini-langage dédié. Celui-ci définit la structure attendue des arguments et la manière dont ils seront transmis aux méthodes de la commande.

Dans tous les cas, `syntax` est un attribut de type chaîne. À partir de celui-ci, les arguments de la commande sont analysés et transmis aux méthodes `refine` (si définie) et `run`.

Ça paraît abstrait ? Pas d'inquiétude, nous allons voir différents exemples, pas à pas, pour illustrer la gestion des arguments.

### Arguments simples

Les arguments les plus simples sont ce qu'on appelait auparavant des « trous à remplir ». Pour éviter toute confusion avec le mot « argument » tel qu'il est utilisé dans la définition des méthodes, nous les appellerons **variables de syntaxe**.

Reprenons notre exemple de `shout` :

> crier J'ai réussi !

Notre commande crier pourrait accepter n'importe quel argument (un mot, plusieurs mots, n'importe quoi). Pour indiquer que la commande accepte exactement une variable de syntaxe, on entoure son nom de chevrons (`<>`). Le nom choisi devient le nom de la variable disponible dans `refine` et `run`.

Par exemple, si nous appelons la variable de syntaxe `message`, l'attribut `syntax` de la commande serait :

```
syntax = "<message>"
```

Passons en revue la commande complète :

```
!command/shout!
parent = "generic/char_command"
name = "crier"
syntax = "<message>"

def run(character, message):
    character.msg(f"Vous criez à tue-tête : {message}")
```

Sauvegardez le worldlet, appliquez-le comme d'habitude.

Quand un joueur tape :

    crier moi aussi

Le moteur :

1. Sépare le nom de la commande (`crier`) des arguments (`moi aussi`).
2. Vérifie la syntaxe, qui spécifie une variable de syntaxe `message`.
3. Assigne tous les arguments (`moi aussi`) à la variable `message`.
4. Appelle la méthode `run` de cette manière :

```python
!command/shout!.run(message="moi aussi")
```

Si vous envoyez la commande ci-dessus, vous verrez :

    Vous criez à tue-tête : moi aussi

Si vous avez défini la méthode optionnelle `refine`, elle sera appelée avant `run` avec les mêmes variables, pouvant éventuellement les modifier avant que `run` ne les reçoive.

> **Pourquoi utiliser `refine` ?**

La méthode `run` exécute la commande. Cependant, la syntaxe statique ne peut pas couvrir tous les cas d'utilisation. La méthode `refine` se place entre l'analyse et l'exécution, vous permettant de :

1. Transformer ou mettre à jour les variables de syntaxe.
2. Rechercher des objets dans des lieux (effectuer une correspondance). Cela ne se fait pas automatiquement.
3. Gérer des situations complexes que l'analyseur de syntaxe ne peut pas exprimer.

Voyons un exemple.

### Raffiner les arguments

```
!command/shout!
parent = "generic/char_command"
name = "crier"
syntax = "<message>"

def refine(character, message):
    message = message.upper()

def run(character, message):
    character.msg(f"Vous criez à tue-tête : {message}")
```

Ici, nous avons ajouté une méthode `refine` qui transforme la variable `message` en majuscules.

En tapant :

    crier moi aussi

On obtient maintenant :

    Vous criez à tue-tête : MOI AUSSI

Voici pourquoi :

- Le moteur appelle d'abord `refine` avec `message="moi aussi"`.
- La méthode `refine` met `message` en majuscules.
- Le `message` modifié est transmis à `run`.
- `run` s'exécute avec `message="MOI AUSSI"`.

Comme `refine` est une méthode, elle ne se limite pas à des transformations statiques et peut effectuer toute opération autorisée par le scripting Pythello ([voir la documentation sur le scripting](./scripting.md)).

### Mots-clés et symboles dans les arguments

Que faire si vous voulez une commande qui prend deux variables de syntaxe ? Par exemple, une commande `get` qui prend un objet dans un conteneur.

À première vue, on pourrait écrire :

```
<object> <container>
```

Mais si le joueur tape :

    get pomme rouge figuier

Comment l'analyseur sait-il quels mots désignent l'objet et lesquels le conteneur ? C'est ambigu.

Il faut un séparateur, soit un symbole, soit un mot-clé.

Exemple avec un symbole :

    get pomme rouge, figuier

En utilisant une virgule comme délimiteur.

Plus couramment dans les jeux, on utilise des mots-clés pour plus de clarté. Le mot-clé `from` est typique :

    get pomme rouge from figuier

Pour spécifier cela dans la syntaxe, écrivez les mots-clés en clair (sans chevrons) :

```
<object> from <container>
```

Voyons la commande complète :

```
!command/get!
parent = "generic/char_command"
name = "get"
syntax = "<object> from <container>"

def run(character, object, container):
    character.msg(f"Vous aimeriez prendre {object} dans {container}.")
```

En tapant :

    get pomme rouge from figuier

On obtient :

    Vous aimeriez prendre pomme rouge dans figuier.

- `<object>` est une variable de syntaxe capturant le premier argument.
- `from` sert de mot-clé séparateur.
- `<container>` capture tout ce qui suit `from`.

> **Que se passe-t-il si l'utilisateur omet `from` ou certains arguments ?**

Par défaut, une erreur d'analyse survient avec un message générique. Vous pouvez fournir un message plus utile en redéfinissant la méthode `parse_error` :

```
!command/get!
parent = "generic/char_command"
name = "get"
syntax = "<object> from <container>"

def run(character, object, container):
    character.msg(f"Vous aimeriez prendre {object} dans {container}.")

def parse_error(character):
    character.msg("Entrez le nom de l'objet, suivi de FROM, suivi du nom du conteneur.")
```

`parse_error` est appelée chaque fois que l'analyse des arguments échoue, vous permettant de guider le joueur avec un message plus clair.

### Légère variante : utiliser des symboles au lieu de mots-clés

Vous pouvez aussi utiliser des délimiteurs comme la virgule en tant que symboles dans la syntaxe :

```
syntax = "<object>, <container>"
```

Le joueur taperait alors :

    get pomme rouge, figuier

Le style que vous choisissez dépend de votre jeu, de vos préférences, et de ce à quoi vos joueurs sont habitués.

### Nombres

Les variables de syntaxe peuvent aussi être typées comme des nombres. Les nombres diffèrent des variables de syntaxe textuelles de deux manières :

- Ils n'acceptent qu'un seul « mot ».
- Ce mot doit être un nombre valide.

Pour indiquer une variable de syntaxe numérique, entourez son nom de symboles `#` :

```
#times#
```

Par exemple, on peut étendre la commande `shout` pour prendre le nombre de fois où crier et le message :

```
!command/shout!
parent = "generic/char_command"
name = "crier"
syntax = "#times# <message>"

def refine(character, times, message):
    message = message.upper()

def run(character, times, message):
    character.msg(f"Vous criez {times} fois à tue-tête : {message}")
    character.msg(f"... ou plutôt : {times * message}")
```

En tapant :

    crier 3 ok

On obtient :

    Vous criez 3 fois à tue-tête : OK
    ... ou plutôt : OKOKOK

Notez que `times` est une variable de syntaxe numérique, tandis que `message` est textuelle.

> **Attendez, vous avez dit plus haut que deux variables d'argument côte à côte causent une ambiguïté ?**

C'est exact, mais les nombres sont un cas particulier : puisqu'un nombre ne peut correspondre qu'à un seul mot, l'analyseur peut différencier si le premier mot est un nombre ou non. Si l'analyse échoue, `parse_error` est appelée.

### Branches optionnelles

Parfois, les commandes peuvent accepter des parties optionnelles. Par exemple, avec la commande `get`, les joueurs pourraient vouloir ramasser quelque chose simplement au sol, sans avoir à spécifier `from <container>` à chaque fois.

Pour définir des parties optionnelles de la syntaxe, entourez-les de parenthèses `()`.

Notre syntaxe d'origine :

```
<object> from <container>
```

Devient :

```
<object> (from <container>)
```

Cela marque `from <container>` comme optionnel.

Ainsi, les deux formes suivantes :

    get pomme rouge

et

    get pomme rouge from figuier

sont valides.

> **Que se passe-t-il si l'argument optionnel est omis ? Qu'advient-il de la variable `container` ?**

Si le joueur ne spécifie pas `from <container>`, la variable `container` n'existe pas par défaut dans `run`. Vous pouvez gérer cela en spécifiant des valeurs par défaut dans la signature de votre méthode.

Voici un exemple :

```
!command/get!
parent = "generic/char_command"
name = "get"
syntax = "<object> (from <container>)"

def run(character, object, container=None):
    if container:
        character.msg(f"Vous aimeriez prendre {object} dans {container}.")
    else:
        character.msg(f"Vous aimeriez ramasser {object} depuis le sol.")
    endif
```

- Nous déclarons explicitement les arguments de la méthode `run`.
- `character` est l'objet personnage (utilisé pour envoyer des messages).
- `object` correspond à la variable de syntaxe `<object>`.
- `container` correspond à `<container>`. Il a une valeur par défaut `None`, donc si le joueur l'omet, la variable existe mais vaut `None`.

Exemples :

    get pomme rouge

Affiche :

    Vous aimeriez ramasser pomme rouge depuis le sol.

Et :

    get pomme rouge from figuier

Affiche :

    Vous aimeriez prendre pomme rouge dans figuier.

Vous pourriez aussi définir la valeur par défaut dans `refine` en y créant la variable si elle manque. Les deux approches sont valides ; choisissez celle qui convient le mieux à vos besoins.

> **Note :** Cela fonctionne bien parce que la branche optionnelle commence par un mot-clé (`from`). Cependant, si vous avez deux variables d'argument adjacentes (une optionnelle et une obligatoire), l'analyseur ne peut pas lever l'ambiguïté sans mot-clé ni symbole. Le moteur ne devine rien et ne fait aucune « magie » de ce genre.

## Pause en cours de commande

Il est assez courant de vouloir faire une pause pendant l'exécution de la méthode `run`. Par exemple, vous pourriez vouloir démarrer une action, attendre une minute, puis donner un retour au joueur. Pythelix est conçu de sorte que :

- Une pause ne **bloque pas** les commandes saisies par ce client ou par d'autres.
- En revanche, deux commandes ne s'exécutent jamais simultanément.

Autrement dit, toutes les commandes (scripts, exécutions de tâches, etc.) sont mises en file d'attente et exécutées une par une. C'est toujours le cas. Ainsi, si vous « geliez » le serveur entier pendant 5 secondes dans votre commande, personne ne pourrait faire quoi que ce soit d'autre pendant ces 5 secondes — pas idéal.

D'un autre côté, les pauses introduisent d'autres considérations :

- Vous pouvez facilement attendre pendant l'exécution d'un script. Mais d'autres peuvent envoyer des commandes pendant que le script est en pause, ce qui signifie que l'état du jeu après la pause peut différer de celui d'avant.
- Cela inclut le même joueur : il peut envoyer des commandes pendant que le script est en pause et pourrait même relancer la même commande, causant potentiellement des pauses imbriquées. En général, il vaut mieux éviter de telles duplications.

Habituellement, on veut faire quelque chose une fois, attendre la fin de la pause, puis permettre que cela se reproduise.

La syntaxe est très simple. Par exemple :

```
def run(character):
    character.msg("Avant la pause")
    wait 5  # Attendre 5 secondes
    character.msg("Après ces cinq secondes")
```

Cet exemple semble simple : vous envoyez un message, attendez 5 secondes, puis envoyez un autre message. Mais considérez que :

- Pendant la pause, le client peut passer à un autre menu ou une autre action, y compris taper une autre commande.
- Le client peut se déconnecter pendant la pause ; cela ne provoquera pas de crash.
- Le serveur peut redémarrer pendant la pause ; la tâche reprendra lorsque le serveur sera de nouveau en ligne, même si le client n'existe peut-être plus. Là encore, cela ne provoquera pas d'erreur.

Vous ne pouvez pas empêcher le client de se déconnecter, ni empêcher les redémarrages du serveur (bien que cela soit votre responsabilité). Autrement dit, évitez de donner des informations importantes **après** ces cinq secondes si elles sont vitales pour la prochaine connexion, car elles pourraient ne jamais être délivrées.

Vous spécifiez la pause en secondes après le mot-clé `wait`. Ce peut être une variable, un entier ou un nombre à virgule. Le mot-clé peut apparaître à l'intérieur de boucles si nécessaire — c'est simplement une construction du langage.

Vous pouvez aussi spécifier une durée, ce qui peut être plus lisible :

```
def run(character):
    character.msg("Avant la pause")
    wait 5m
    client.msg("Après cinq longues minutes")
```

Utiliser une durée (un nombre suivi d'une unité : `s` pour secondes, `m` pour minutes, etc.) peut être plus lisible.

## Demander des précisions au personnage

Certaines commandes peuvent avoir besoin de demander des informations supplémentaires au joueur. Le scénario le plus courant est une confirmation : « Êtes-vous sûr de vouloir continuer ? Tapez 'oui' ou 'non'. ».

Ce genre de chose peut être géré avec les fonctions intégrées `ask` ou `choice`.

`ask` demande simplement une information au joueur :

    nom = ask(character, "Quel est votre nom, déjà ?")
    # Faites ce que vous voulez avec le nom

Par exemple, une commande qui demande la couleur des yeux du personnage peut être écrite ainsi :

```
!command/eye!
parent = "generic/char_command"
category = "General"
name = "eye"

def run(character):
    couleur = ask(character, "Quelle est la couleur des yeux de votre personnage ?")
    character.msg(f"Vous avez choisi la couleur des yeux : {couleur}.")
```

Vous pouvez sauvegarder et appliquer le worldlet comme d'habitude. Dans votre client MUD, si vous tapez `eye`, vous devriez voir :

    Quelle est la couleur des yeux de votre personnage ?

Et vous pouvez taper `bleu` par exemple pour obtenir le message :

    Vous avez choisi la couleur des yeux : bleu.

> D'autres joueurs peuvent-ils entrer des commandes entre-temps ?

Oui, heureusement. Ce n'est pas bloquant. Seul le joueur actuel est en attente d'une saisie. Mais les autres peuvent exécuter des commandes, y compris recevoir leurs propres demandes d'information.

> Que se passe-t-il si le joueur se déconnecte avant de donner sa couleur d'yeux ?

Dans ce cas, la question lui sera reposée à la reconnexion (une fois son nom d'utilisateur et son mot de passe saisis). Il en irait de même si le serveur s'arrêtait puis redémarrait. Les demandes de saisie sont sauvegardées comme les tâches en pause.

> Qu'est-ce qui empêche le joueur de saisir une couleur invalide ?

Rien. C'est une question à réponse libre. Ce que vous pourriez faire, c'est utiliser `ask` dans une boucle jusqu'à ce que la réponse vous convienne.

Mais la fonction `choice` est peut-être plus adaptée ici. Elle suppose que seules certaines réponses sont valides.

Vous devez spécifier quelles réponses sont acceptées. Voyons un exemple simple :

```
!command/eye!
parent = "generic/char_command"
category = "General"
name = "eye"
syntax = "<color>"

def run(character, color):
    choices = {"oui": True, "non": False}
    prompt = f"Vous avez choisi la couleur {color}. Êtes-vous sûr ?"
    retry = "Tapez 'oui' ou 'non'"

    if choice(character, choices, prompt=prompt, retry=retry):
        character.msg("Eh bien, si vous êtes sûr, enregistrons votre choix.")
    else:
        character.msg("Annulé.")
    endif
```

D'abord, remarquez le dictionnaire `choices` : il contient les choix comme clés (de simples chaînes) et n'importe quoi comme valeur (ici, un booléen, soit `True`, soit `False`). Cet ensemble de choix signifie simplement : si le personnage tape `oui`, retourner `True`, s'il tape `non`, retourner `False`. Sauvegardez et appliquez. Vous pouvez ensuite essayer la commande :

    > eye bleu

Et vous devriez voir :

    Vous avez choisi la couleur bleu. Êtes-vous sûr ?

Si vous tapez `oui`, vous devriez voir :

    Eh bien, si vous êtes sûr, enregistrons votre choix.

Si vous tapez `non`, vous devriez voir :

    Annulé.

Et si vous tapez autre chose, comme `je ne sais pas`, vous devriez voir :

    Tapez 'oui' ou 'non'

Et vous devez réessayer. Encore une fois, si le client se déconnecte puis se reconnecte, la même question lui sera reposée.

Un autre exemple avec la couleur des yeux ? Supposons que vous souhaitiez proposer une liste limitée de choix. Le code est un peu plus élaboré, mais pas beaucoup :

```
!command/eye!
parent = "generic/char_command"
category = "General"
name = "eye"

def run(character):
    couleurs = ("bleu", "vert", "marron", "orange", "noir", "blanc")
    choices = {}
    prompt = "Entrez la couleur des yeux sous forme de numéro :"
    i = 1

    for couleur in couleurs:
        choices[str(i)] = couleur
        prompt += f"\n  {i} pour {couleur}"
        i += 1
    done

    prompt += f"\nEntrez un numéro entre 1 et {len(couleurs)} :"
    retry = "Entrez un numéro valide."
    couleur = choice(character, choices, prompt=prompt, retry=retry)
    character.msg(f"Vous avez choisi la couleur des yeux {couleur}.")
```

Si vous tapez `eye` sans argument, vous devriez voir :

    Entrez la couleur des yeux sous forme de numéro :
      1 pour bleu
      2 pour vert
      3 pour marron
      4 pour orange
      5 pour noir
      6 pour blanc
    Entrez un numéro entre 1 et 6 :

Si vous tapez `4` par exemple, vous obtiendrez :

    Vous avez choisi la couleur des yeux orange.

Et bien sûr, si vous tapez autre chose qu'un numéro de 1 à 6, vous devrez réessayer.

## Rechercher des entités valides dans un lieu

Beaucoup de commandes ont besoin de travailler avec des entités valides. Pensez à notre commande `get` : elle extrait du texte, ce qui est bien, mais si elle ne peut pas trouver les entités qui utilisent réellement ce texte comme nom, c'est un peu compliqué. Pythelix ne permet pas de chercher directement depuis l'analyseur de commande, car beaucoup de choses (comme l'origine de la recherche) ne sont pas souvent identiques.

Il n'en reste pas moins que nous voulons une commande get avec `<object>` comme syntaxe qui cherche la bonne entité. Si l'utilisateur tape `get pomme rouge`, nous ne voulons pas le texte `pomme rouge`, mais l'entité portant ce nom.

La correspondance, ou recherche d'une entité à partir d'un nom, se fait généralement en trois étapes :

1. D'abord, on extrait l'argument sous forme de texte, comme on l'a fait auparavant.
2. La méthode `refine` recherche l'entité (ou les entités) portant ce nom.
3. La méthode `run` décide quoi faire avec ces entités.

La correspondance est un sujet complexe. Comme les jeux se comportent généralement de manière très différente, Pythelix essaie de ne rien supposer concernant la correspondance. Il offre des fonctionnalités génériques qui peuvent généralement être étendues pour s'adapter à votre jeu.

Mais voyons un exemple basique. Pour faire une commande `get` qui ramasse un objet au sol (vous pouvez taper `get pomme rouge` s'il y a une pomme au sol), le worldlet ressemble à ceci :

```
!command/get!
parent = "generic/char_command"
name = "get"
category = "General"
syntax = "<object>"

def refine(character, object):
    to_pick = search.match(character.location, object, viewer=character)

def run(character, to_pick):
    # Changer la localisation de l'objet
    for item in to_pick:
        item.location = character
    done

    # Afficher les noms des objets
    for name in names.group(to_pick, viewer=character):
        character.msg(f"Vous ramassez {name}.")
    done
```

En résumé :

- L'attribut `syntax` contient le nom de l'objet ;
- La méthode `refine` utilise `search.match` pour trouver les entités portant le bon nom (dans le lieu du personnage, vraisemblablement une salle) ;
- La méthode `run` exécute deux boucles : l'une pour déplacer la localisation de tous les objets de la salle vers le personnage (placement dans l'inventaire), l'autre pour afficher les noms des objets (on utilise `names.group` pour gérer correctement les noms au pluriel).

Comme nous l'avons dit, la correspondance est un sujet complexe et ceci n'est qu'un aperçu. Pour en savoir plus, lisez la [documentation sur la correspondance](./match.md).

## FAQ sur les commandes

- <details markdown="1">
  <summary>Pourquoi les commandes ne sont-elles pas de simples méthodes ?</summary>

  Si vous connaissez LambdaMOO, vous savez peut-être que les commandes peuvent simplement être des verbes définis sur des objets. Pythelix pourrait théoriquement fonctionner de la même manière : les commandes seraient simplement des méthodes sur des entités.

  Cependant, Pythelix a fait un choix de conception différent car :

  - Trouver la méthode à exécuter nécessiterait de parcourir de nombreux candidats, ce qui compliquerait le moteur.
  - Les commandes définies sur différents objets rendent plus difficile la création d'un système d'aide centralisé.
  - Les joueurs pourraient invoquer des commandes dans un mauvais contexte et recevoir des erreurs peu utiles comme « Je ne comprends pas » ou « Hein ? ».
  - Des conflits pourraient survenir si le même verbe est défini sur plusieurs entités.

  Centraliser les commandes en tant qu'entités virtuelles offre des avantages clairs :

  - Les commandes sont regroupées au même endroit, simplifiant la gestion et la génération de l'aide.
  - L'analyse, la gestion des arguments et le signalement des erreurs sont cohérents.
  - Les conflits sont minimisés.
  - Les commandes peuvent toujours appeler des méthodes (verbes) sur les objets correspondants.

  Ce choix de conception améliore la clarté et la maintenabilité sans limiter votre capacité à construire des interactions riches.

  </details>

Ceci couvre les bases de la création et de la gestion des commandes dans Pythelix, y compris les attributs, les méthodes, la syntaxe, l'analyse des arguments et les raffinements. Pour approfondir le scripting, consultez la [documentation sur le scripting](./scripting.md). Vous pourriez aussi vouloir consulter la [documentation sur les méthodes](./methods.md) qui explique plus en détail le concept de signature de méthode et d'arguments par défaut.
