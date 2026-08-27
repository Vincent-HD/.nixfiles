# Étude de faisabilité — compilateur TypeScript → Nix

> **Statut :** note de recherche consolidée
>
> **Date :** 27 août 2026
>
> **Périmètre :** documentation officielle de Nix/NixOS et dépôts officiels des projets cités. Les conclusions sont documentaires : aucun prototype de compilateur n’a été implémenté ni exécuté pour cette note.

## Convention de lecture

- **Fait sourcé** : comportement décrit par la documentation officielle ou visible dans le code source officiel cité.
- **Inférence** : conséquence technique déduite de ces faits ; elle n’est pas présentée comme une garantie du projet concerné.
- **Non vérifié** : point qui demande une expérimentation, un audit plus large ou une vérification contre les versions effectivement verrouillées.

## Résumé exécutif

**Faisabilité conditionnelle.** Un compilateur TypeScript → Nix est raisonnable s’il compile un langage TypeScript restreint — idéalement un DSL typé de configuration — vers un sous-ensemble explicite d’expressions Nix, de modules NixOS/Home Manager ou de fragments de flake. Les projets `dhall-nix` et `tnix` montrent qu’une couche source typée et une génération de Nix sont techniquement crédibles, mais leurs limites documentées montrent aussi que le système de modules et les idiomes réels de Nix ne se réduisent pas à des données JSON.

En revanche, un transpileur général qui accepterait du TypeScript arbitraire et préserverait son comportement dans du Nix arbitraire serait un projet de difficulté très élevée, et probablement un mauvais objectif produit. Les différences de sémantique — évaluation paresseuse, portée lexicale, fonctions et attributs plutôt que classes/objets JavaScript, chemins et contexte de chaînes, builtins et dérivations — imposent soit une bibliothèque d’exécution, soit une restriction forte du langage source. Cette conclusion est une **inférence**, pas une impossibilité formelle démontrée.

La trajectoire recommandée est donc :

1. commencer par un générateur de valeurs et de fragments Nix déterministes ;
2. ajouter ensuite un backend de modules ciblé, avec le système de modules NixOS/Home Manager comme autorité de fusion et de typage ;
3. ne générer un flake complet qu’en dernier, en laissant Nix gérer le verrouillage des inputs.

## 1. Ce que signifie « TypeScript → Nix »

Il faut séparer trois problèmes qui sont souvent confondus :

| Cible | Sens pratique | Faisabilité indicative |
| --- | --- | --- |
| Valeurs Nix structurées | Objets TypeScript typés → attrsets/listes/chaînes Nix | Bonne, si les types de sortie sont limités |
| DSL TypeScript → expressions ou modules Nix | Le TypeScript décrit des références `pkgs`, des options, des conditions et des imports autorisés | Réaliste, mais nécessite une IR et des diagnostics de domaine |
| TypeScript arbitraire → Nix sémantiquement équivalent | Traduction générale de classes, exceptions, mutations, async, packages et runtime JS | Très difficile ; cible à éviter |

**Inférence.** Le produit viable ressemble davantage à un compilateur de configuration ou à un générateur de modules qu’à un transpileur de langage général. Le type de cible doit être choisi explicitement : expression Nix, module NixOS, module Home Manager, module `flake-parts`, ou flake complet.

Un nom comme `get_json_from_json` n’est pas un builtin Nix standard
identifié dans la référence officielle. C’est vraisemblablement le nom d’un
helper ajouté par un projet ou par un générateur. Dans ce dépôt, la forme
équivalente visible dans
[/home/vincent/.nixfiles/modules/dms/dms.nix](/home/vincent/.nixfiles/modules/dms/dms.nix)
est `builtins.fromJSON (builtins.readFile ./assets/generated-settings.json)` :
une primitive lit le fichier, l’autre parse la string JSON. Le nom long peut
être pratique pour un helper, mais il ne faut pas le confondre avec une
feature du langage.

Pour lire une expression imbriquée, il faut commencer par la gauche et
identifier le namespace :

```text
lib.getExe pkgs.hello
│   │      └─ argument : sélection de l’attribut hello dans pkgs
│   └─ sélection de la fonction getExe dans lib
└─ application : la fonction reçoit l’argument précédent
```

Puis une expression comme
`builtins.fromJSON (builtins.readFile ./settings.json)` se lit en
deux étapes : les parenthèses calculent d’abord le contenu du fichier, puis
`fromJSON` transforme la string obtenue en valeur Nix. Nix autorise
l’application sans parenthèses autour de la fonction et de son argument ; les
parenthèses servent ici à rendre l’imbrication explicite. Cette convention
explique une grande partie de l’impression « make/get/exe » : les mots ne sont
pas des instructions magiques, mais des sélections de fonctions et des
applications de fonctions provenant de namespaces différents.

Sur la machine de travail, `nix --version` retourne Nix 2.34.8. Les
tests locaux de parsing et d’évaluation ont été réalisés avec cette version,
tandis que les liens de référence vers le manuel et le source parser ciblent
Nix 2.35.2. Cette différence est volontairement signalée : un générateur
devrait pinner sa target version et vérifier les features activées.

## 2. Limites structurelles de Nix et de son AST

### 2.1 Le langage cible n’est pas un format de données

**Faits sourcés.** Le manuel Nix décrit un langage d’expressions avec littéraux, listes, ensembles d’attributs, ensembles récursifs, `let`, `inherit`, fonctions, conditions, assertions et `with` ([syntaxe Nix](https://nix.dev/manual/nix/2.35/language/syntax.html)). Les valeurs évaluées sont notamment des entiers, flottants, booléens, chaînes, chemins, `null`, attrsets, listes, fonctions et valeurs externes ([types Nix](https://nix.dev/manual/nix/2.35/language/types.html)).

L’évaluation est à portée lexicale et par besoin : Nix peut conserver une expression et son environnement dans une thunk, et ne l’évalue que lorsqu’une valeur est nécessaire ([évaluation](https://nix.dev/manual/nix/2.35/language/evaluation.html), [portée](https://nix.dev/manual/nix/2.35/language/scope.html)). Les ensembles récursifs autorisent les références mutuelles ; une définition mal fondée peut donc déclencher une récursion infinie ([ensembles récursifs](https://nix.dev/manual/nix/2.35/language/syntax.html#recursive-sets)).

Les chemins ne sont pas de simples chaînes : ils ont un type distinct, une résolution relative au fichier courant et des interactions avec le store lorsqu’ils sont interpolés ou importés. Les chaînes possèdent également un contexte qui peut transporter de l’information liée aux dérivations ([types Nix](https://nix.dev/manual/nix/2.35/language/types.html)).

**Inférences pour TypeScript.** Une sérialisation naïve `object → attrset` ne peut pas représenter correctement une fonction Nix, un chemin, une référence à un paquet, une dérivation, un import ou une expression paresseuse. L’IR doit donc distinguer au minimum :

- valeur littérale et expression à évaluer ;
- chaîne et chemin ;
- attrset de données et attrset récursif ;
- référence symbolique (`pkgs.foo`, `lib.mkIf`, `inputs.nixpkgs`) et chaîne portant le même texte ;
- fonction Nix et donnée décrivant une fonction ;
- condition, assertion, import et appel de builtin.

Le frontend ne devrait pas convertir automatiquement une valeur JavaScript quelconque. Les références vers l’environnement Nix devraient être des constructeurs ou types TypeScript explicites, par exemple une référence de paquet ou une expression `mkIf`, plutôt qu’un accès dynamique arbitraire à un objet.

### 2.2 Grammaire, identifiants et attributs dynamiques

**Faits sourcés.** La grammaire officielle actuelle est un parseur Bison dans [`src/libexpr/parser.y`](https://github.com/NixOS/nix/blob/master/src/libexpr/parser.y), alimenté par un lexer Flex dans [`src/libexpr/lexer.l`](https://github.com/NixOS/nix/blob/master/src/libexpr/lexer.l). La grammaire couvre notamment les lambdas, `let`, `if`, `assert`, `with`, les opérateurs, les chemins, l’interpolation `${ ... }`, les listes et les attrsets.

Les noms d’attributs peuvent être des identifiants ou des chaînes ; un chemin comme `a.b.c` construit des attrsets imbriqués ([syntaxe des attrsets](https://nix.dev/manual/nix/2.35/language/syntax.html#attribute-sets)). Le lexer accepte une classe d’identifiants limitée et réserve des mots comme `if`, `then`, `else`, `let`, `in`, `rec`, `inherit` et `with`. Les clés arbitraires et interpolées sont donc différentes d’un nom d’identifiant statique.

Le parseur source gère les noms dynamiques, rejette les doublons selon le contexte et construit les chemins d’attributs imbriqués. Le fichier [`nixexpr.hh`](https://github.com/NixOS/nix/blob/master/src/libexpr/include/nix/expr/nixexpr.hh) expose les nœuds internes correspondant aux entiers, chaînes, chemins, variables, sélections, attrsets, listes, lambdas, appels, `let`, `with`, conditions, assertions et opérateurs. [`parser-state.hh`](https://github.com/NixOS/nix/blob/master/src/libexpr/include/nix/expr/parser-state.hh) montre que l’état du parseur porte aussi les positions, commentaires, symboles, chemins de base et la construction d’attrsets.

**Inférences pour l’émetteur.** Le backend doit avoir des fonctions dédiées pour :

- décider quand une clé peut être émise comme identifiant et quand elle doit être une chaîne ;
- échapper les chaînes et les interpolations sans confondre texte et expression ;
- encoder les chemins en tant que chemins Nix, sans les dégrader en chaînes ;
- détecter les collisions produites par des chemins d’attributs et les doublons ;
- conserver la différence entre un attrset ordinaire, un attrset `rec` et une définition issue d’un module ;
- produire des diagnostics reliés à l’emplacement TypeScript d’origine.

Dans les sources Nix consultées, la syntaxe est définie par cette grammaire et aucune API documentaire de macros ou d’extension syntaxique utilisateur n’a été vérifiée. Il faut donc traiter Nix comme une cible à syntaxe fixe ; c’est un **point non vérifié** au sens d’une garantie d’API publique, pas une affirmation que le langage ne pourra jamais évoluer.

### 2.3 AST officiel : autorité d’implémentation, contrat d’intégration incertain

**Faits sourcés.** Le code source Nix représente l’AST par des classes C++ internes (`ExprInt`, `ExprString`, `ExprPath`, `ExprAttrs`, `ExprLambda`, etc.) et le parseur appelle cette représentation. La commande [`nix-instantiate`](https://nix.dev/manual/nix/2.35/command-ref/nix-instantiate) propose `--parse` pour parser une expression et imprimer un AST sous forme d’expression Nix, tandis que `--eval` évalue cette expression ; l’évaluation reste paresseuse sauf demande de stricte récursion.

Cela donne une validation syntaxique officielle, mais pas nécessairement une API AST stable pour un programme TypeScript. La sortie de `--parse` est du texte Nix normalisé, non un schéma JSON documenté de nœuds, et les classes du header C++ sont des détails d’implémentation du dépôt source.

**Inférence d’architecture.** Il est plus sûr de générer du texte Nix déterministe, puis de le faire parser et évaluer par la version de Nix ciblée, que de dépendre directement de l’AST C++ interne. Une bibliothèque AST peut être ajoutée pour l’édition ou la conservation des positions, mais elle ne doit pas remplacer Nix comme oracle final de syntaxe et d’évaluation.

### 2.4 Outils AST et de validation existants

| Projet officiel | Fait vérifié | Utilité et réserve |
| --- | --- | --- |
| [Nix parser (`NixOS/nix`)](https://github.com/NixOS/nix/tree/master/src/libexpr) | Parser/évaluateur de référence, avec AST C++ interne | Autorité finale ; interface d’intégration stable non vérifiée |
| [`nix-instantiate --parse`](https://nix.dev/manual/nix/2.35/command-ref/nix-instantiate) | Parse et réimprime une expression Nix | Bon smoke test ; format de sortie non vérifié comme contrat d’IR |
| [`rnix-parser`](https://github.com/nix-community/rnix-parser) | Parseur Rust basé sur `rowan`, avec spans et conservation du texte ; son README décrit un arbre pouvant être réimprimé à l’identique, y compris avec des nœuds d’erreur | Intéressant pour formatter/refactoring/source maps ; binding TypeScript et compatibilité exacte avec la version de Nix cible non vérifiés |
| [`tree-sitter-nix`](https://github.com/nix-community/tree-sitter-nix) | Grammaire Nix pour Tree-sitter, avec corpus et générateur de parser dans le dépôt | Adapté à l’édition et à une validation syntaxique rapide ; équivalence complète avec l’évaluateur Nix non vérifiée |
| [`nixfmt`](https://github.com/NixOS/nixfmt) | Formatter officiel du code Nix | Étape finale de présentation ; ce n’est ni un type-checker ni une IR de compilation |
| [`nixd`](https://github.com/nix-community/nixd) | Language server qui s’appuie sur l’évaluation Nix et documente l’inspection des options NixOS, Home Manager et `flake-parts` | Bon modèle pour les diagnostics liés aux options ; les capacités exactes dépendent du contexte et de la version évalués |

## 3. Modules NixOS/Home Manager et flakes

### 3.1 Le système de modules est une évaluation de fixpoint, pas un simple merge JSON

**Faits sourcés.** La documentation NixOS décrit une configuration modulaire où les modules peuvent définir `imports`, `options` et `config`. Les définitions multiples sont combinées selon le type de l’option ; par exemple, les listes se concatènent, tandis que certaines options doivent être uniques. Les priorités et constructeurs tels que `mkBefore`, `mkForce` et `mkMerge` modifient cette fusion ([écriture de modules NixOS](https://nixos.org/manual/nixos/stable/#sec-writing-modules), [options et modules](https://nixos.org/manual/nixos/stable/options.html)).

Le champ `config` vu par un module est la configuration fusionnée complète. La paresse permet des configurations autoréférentielles lorsque chaque valeur individuelle ne dépend pas directement d’elle-même ; une condition `if` placée au mauvais niveau peut toutefois provoquer une récursion infinie. La documentation recommande `mkIf` pour pousser une condition dans les définitions concernées ([conditionnels de modules](https://nixos.org/manual/nixos/stable/#sec-using-mkIf)).

L’implémentation générique est [`lib/modules.nix`](https://github.com/NixOS/nixpkgs/blob/master/lib/modules.nix) et l’interface est exposée par [`lib.evalModules`](https://nixos.org/manual/nixpkgs/unstable/#module-system). Le code distingue `specialArgs`, nécessaires au calcul statique de la structure des imports, de `_module.args`, disponibles après cette résolution. Les modules peuvent être des attrsets ou des fonctions recevant des arguments comme `lib`, `config`, `options`, `pkgs` et `specialArgs`.

NixOS assemble ensuite ces modules avec [`eval-config.nix`](https://github.com/NixOS/nixpkgs/blob/master/nixos/lib/eval-config.nix) et expose l’usage courant `nixpkgs.lib.nixosSystem { modules = [ ... ]; }` dans le [`flake.nix` de nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/flake.nix).

Home Manager réutilise une architecture modulaire mais ajoute son propre contexte. Son module NixOS expose `home-manager.users`, transmet des arguments comme `osConfig` et `nixosConfig`, et permet `home-manager.extraSpecialArgs` et `sharedModules` ([intégration NixOS de Home Manager](https://github.com/nix-community/home-manager/blob/master/docs/manual/installation/nixos.md)). Le code de [`modules/modules.nix`](https://github.com/nix-community/home-manager/blob/master/modules/modules.nix) configure cette évaluation avec la bibliothèque Home Manager et un ensemble de modules de base ; Home Manager peut utiliser un `pkgs` privé ou celui de NixOS selon la configuration.

**Inférences pour un compilateur.**

- Aplatir tous les modules TypeScript en un objet final détruirait les priorités, les conditions, les types, les assertions et les valeurs par défaut. Le compilateur doit émettre des définitions de modules et laisser `evalModules` effectuer la fusion.
- `imports` doit être calculable pendant la résolution de la structure des modules. Les imports dynamiques dépendant de `config` ne doivent pas être cachés dans du TypeScript ; ils doivent être matérialisés statiquement ou passer par des arguments explicites.
- Un backend doit déclarer son contexte cible : `nixosModule`, `homeManagerModule` ou module `flake-parts`. Une sortie qui suppose `pkgs`/`lib` sans préciser le contexte produira des erreurs difficiles à diagnostiquer.
- Une vérification TypeScript des noms et types d’options est possible seulement contre un ensemble précis de modules et de versions. La vérification d’autorité reste l’évaluation Nix ; l’inspection d’un arbre `.options` à la manière documentée par `nixd` est une piste, pas une garantie d’API stable.

### 3.2 Génération NixOS/Home Manager : formes de sortie recommandées

Une forme de module généré peut rester très petite :

```nix
{ lib, pkgs, config, ... }:
{
  imports = [ ];
  options = { };
  config = { };
}
```

La forme est simple ; la difficulté est la signification des définitions. **Inférence :** l’IR devrait représenter séparément `imports`, déclarations d’options, définitions de configuration, assertions, priorités et conditions. Un champ TypeScript qui signifie « valeur forcée » doit produire explicitement `lib.mkForce`, et non un attrset particulier que le module evaluator ne reconnaîtrait pas.

Pour Home Manager, le générateur devrait également encoder la cible et les arguments disponibles. Un module généré pour `home-manager.users.vincent` ne doit pas être considéré comme interchangeable avec un module NixOS système, même si les deux sont des fonctions Nix.

### 3.3 Flakes : structure, systèmes et verrouillage

**Faits sourcés.** La documentation source officielle des flakes décrit un `flake.nix` comme un attrset contenant typiquement `description`, `inputs` et `outputs`. `outputs` est une fonction recevant les outputs des flakes d’input, y compris `self`, et retourne un attrset ; certains noms d’outputs ont des conventions attendues par les commandes Nix ([documentation source des flakes](https://github.com/NixOS/nix/blob/master/src/nix/flake.md), [commande `nix flake`](https://nix.dev/manual/nix/2.35/command-ref/new-cli/nix3-flake.html)).

Les inputs peuvent être des URLs ou des spécifications structurées, et `follows` permet de réutiliser un input transitif. Le fichier `flake.lock` représente le graphe verrouillé des dépendances et est géré par les opérations de flake. Les flakes restent documentés comme une interface expérimentale ([concepts des flakes](https://nix.dev/concepts/flakes.html)). Le modèle ne fournit pas automatiquement un axe `system` : les outputs multi-systèmes doivent l’exprimer explicitement.

**Inférences pour la génération.** Un compilateur doit traiter comme données de première classe :

- les noms d’inputs et leurs relations `follows` ;
- l’axe des systèmes (`x86_64-linux`, `aarch64-darwin`, etc.) ;
- la distinction entre `nixosConfigurations`, `homeConfigurations`, `packages`, `checks` et autres outputs ;
- la frontière entre le texte généré de `flake.nix` et le graphe de `flake.lock`.

Il est préférable de générer le flake ou un module `flake-parts` sans réécrire directement le lockfile. Le CLI Nix doit rester responsable de `nix flake lock`/`update` et de la validation. Générer un flake complet est donc une étape plus risquée qu’émettre un module consommé par un flake écrit à la main.

Le projet [flake-parts](https://github.com/hercules-ci/flake-parts) est un précédent pertinent : il organise les outputs de flake avec un système de modules et des axes par système. **Inférence :** un générateur TypeScript peut plus facilement cibler un fragment de module `flake-parts` qu’inventer une nouvelle convention de composition, à condition de verrouiller la version de `flake-parts` et d’en connaître les options.

## 4. Projets existants pertinents

Les projets suivants ont été vérifiés dans leurs dépôts officiels. Ils ne sont pas tous des compilateurs TypeScript → Nix ; leur intérêt est d’éclairer une partie du problème.

### 4.1 Générateurs et langages de configuration

| Projet officiel | Ce que le dépôt établit | Leçon pour TypeScript → Nix |
| --- | --- | --- |
| [`nixos-generate-config`](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/tools/nixos-generate-config.pl) et ses templates [`tools.nix`](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/tools/tools.nix) | NixOS génère déjà des fichiers matériels, une `configuration.nix` et un template de `flake.nix` adapté à une machine | Précédent concret de génération de texte Nix ; générateur spécialisé, pas compilateur de langage |
| [`dhall-nix`](https://github.com/dhall-lang/dhall-haskell/tree/main/dhall-nix) | Fournit une compilation Dhall → Nix et présente Dhall comme une manière typée de programmer Nix | Preuve de faisabilité d’une source typée ; le README le qualifie de proof of concept et documente des incompatibilités avec la récursion générale, `callPackages`, les modules NixOS, `listToAttrs` et certains idiomes de Nix |
| [`tnix`](https://github.com/ubugeeei-prod/tnix) et son [architecture](https://github.com/ubugeeei-prod/tnix/blob/main/docs/architecture.md) | Langage progressivement typé qui compile `.tnix` vers `.nix`, efface les types et conserve une sémantique d’exécution Nix ; le dépôt décrit un parseur, un type-checker, une IR/AST et un émetteur | C’est le précédent architectural le plus proche : couche typée + sortie Nix ordinaire. Le projet choisit un sous-ensemble et demande de conserver certains morceaux en Nix ; maturité et couverture réelle restent non vérifiées |
| [`node2nix`](https://github.com/svanderburg/node2nix/blob/master/README.md) | Génère plusieurs expressions Nix à partir de `package.json` et de lockfiles npm, avec des expressions dédiées aux paquets et à l’environnement | Montre qu’un générateur par domaine peut être utile ; ne traite pas le TypeScript ni le langage Nix général. Le README rappelle aussi les problèmes d’échappement des noms d’attributs |
| [`dream2nix`](https://github.com/nix-community/dream2nix/blob/main/README.md) | Framework modulaire de packaging automatisé pour plusieurs écosystèmes | Précédent pour séparer un frontend par écosystème d’une représentation et de modules Nix ; le dépôt signale des APIs instables et des refactorings en cours |
| [`npmlock2nix`](https://github.com/nix-community/npmlock2nix/blob/master/README.md) | Parse `package.json`/`package-lock.json` dans Nix et produit des dérivations sans code automatiquement généré | Alternative importante : certains problèmes se résolvent mieux par une bibliothèque Nix évaluant une structure que par la génération de fichiers |
| [`cabal2nix`](https://github.com/NixOS/cabal2nix) | Génère des instructions de build Nix depuis Cabal ; le dépôt contient aussi `language-nix`, bibliothèque de parsing/rendu d’un sous-ensemble de Nix | Autre preuve qu’un générateur spécialisé peut être robuste sans viser une traduction générale |
| [`nickel`](https://github.com/nickel-lang/nickel) | Langage de configuration avec fonctions, records, types graduels et contrats ; le dépôt le présente comme une évolution de certaines idées de Nix et documente des exports JSON/YAML/TOML | Alternative de langage à étudier si l’objectif est une configuration typée ; aucun backend Nix complet n’a été vérifié dans les sources consultées |

Le dépôt officiel de TypeScript documente une API de compilateur avec `Program`, `SourceFile`, `TypeChecker`, factories et printer ([Using the Compiler API](https://github.com/microsoft/TypeScript/wiki/Using-the-Compiler-API)). La même documentation avertit que cette API n’est pas encore considérée comme stable. **Inférence :** un frontend TypeScript devrait pinner sa version, isoler l’adaptateur vers l’API et éviter de laisser l’AST TypeScript devenir l’IR publique du compilateur.

### 4.2 Type-checking Nix avec les outils de TypeScript

[TypeNix](https://github.com/ryanrasti/typenix) constitue le précédent le plus
proche de l’idée « utiliser TypeScript sans réécrire tout Nix ». Son approche
parse les fichiers Nix avec tree-sitter-nix, convertit cet arbre vers un
TypeScript AST, puis réutilise le binder, le checker et le LSP de TypeScript.
Le projet annonce aussi un traitement spécifique des fixed points et des
concepts nixpkgs comme Lib, Stdenv, Platform et Derivation.

Cette approche ne transforme pas du TypeScript en Nix : elle applique un
type-checker TypeScript à du Nix. C’est précisément sa force pour la fidélité
sémantique. Ses limites de prototype, comme la nécessité d’annotations
explicites à certains endroits et un traitement spécial de nixpkgs/by-name,
montrent également qu’un système de types pour Nix doit connaître l’évaluation
et les conventions du monde Nix.

La conclusion pratique est double :

- si le besoin prioritaire est le type safety, TypeNix mérite une évaluation
  avant de construire un nouveau compiler ;
- si le besoin prioritaire est d’écrire réellement des fichiers TypeScript,
  TypeNix ne suffit pas et il faut ajouter le frontend/staging décrit plus loin.

Sources : [TypeNix README](https://github.com/ryanrasti/typenix) et
[tnix language design](https://github.com/ubugeeei-prod/tnix/blob/main/docs/language-design.md).

### 4.3 Bibliothèques de parsing, AST et inspection

| Projet | Position dans une architecture possible | Statut à ne pas confondre |
| --- | --- | --- |
| [`rnix-parser`](https://github.com/nix-community/rnix-parser) | CST/AST avec spans, nœuds d’erreur et conservation du texte, utile pour source maps, refactoring et édition | Parseur tiers de l’écosystème ; binding JS/TS et parité avec la grammaire Nix courante non vérifiés |
| [`tree-sitter-nix`](https://github.com/nix-community/tree-sitter-nix) | Parser incrémental rapide pour l’éditeur et la validation syntaxique | Une grammaire/CST n’est pas l’évaluateur Nix ; équivalence sémantique non vérifiée |
| [`nixfmt`](https://github.com/NixOS/nixfmt) | Normalisation après émission | Formatter, pas générateur d’AST ni validateur d’options |
| [`nixd`](https://github.com/nix-community/nixd) et sa [configuration](https://github.com/nix-community/nixd/blob/main/nixd/docs/configuration.md) | Montre comment des outils peuvent évaluer un flake et inspecter `nixosConfigurations.<name>.options` ou `homeConfigurations.<name>.options` | Bonne piste pour l’expérience de diagnostic ; dépend d’un contexte Nix évalué et non d’un simple parsing |
| [`hnix`](https://github.com/haskell-nix/hnix) | Réimplémentation Haskell du langage Nix, avec parser, pretty-printer, évaluateur et type checker dans le dépôt | Utile pour comparer des implémentations ; ne doit pas être supposé équivalent à l’évaluateur officiel sans tests ciblés |

### 4.4 Ce qui n’a pas été établi

Dans les dépôts officiels consultés, je n’ai pas vérifié l’existence d’un compilateur général TypeScript → Nix mature et maintenu. Cette phrase signifie « non trouvé dans ce périmètre de recherche », et non « aucun projet n’existe ». `dhall-nix`, `tnix` et les générateurs de packaging sont des précédents partiels, avec des objectifs et des garanties différents.

## 5. Architecture proposée

### 5.1 Pipeline

```text
Source TypeScript / DSL
        ↓
Program + type-checker TypeScript
        ↓
Validation de la cible et résolution des imports statiques
        ↓
IR Nix typée (expressions, modules, flakes)
        ↓
Émetteur Nix déterministe + source map
        ↓
parse / format / eval Nix
        ↓
evalModules, nixosSystem, Home Manager ou nix flake check
```

Ce pipeline sépare le type-checking de la sémantique Nix. Le TypeScript vérifie ce qu’il peut connaître statiquement ; Nix résout les inputs, builtins, paquets, imports et options réellement présents dans l’environnement verrouillé.

### 5.2 Frontend TypeScript restreint

**Proposition — inférence.** Ne pas exécuter du TypeScript arbitraire pendant la compilation. Définir plutôt une API/DSL dont les constructeurs représentent explicitement :

- chaînes, nombres, booléens, `null`, listes et records ;
- chemins Nix et références de store déclarés ;
- références de paquets et de bibliothèques ;
- appels et fonctions Nix autorisés ;
- `mkIf`, `mkMerge`, `mkBefore`, `mkForce`, assertions et imports ;
- modules NixOS/Home Manager/`flake-parts` et outputs par système.

Le compilateur peut utiliser `Program` et `TypeChecker` de l’API TypeScript, mais doit transformer immédiatement l’AST vers sa propre IR. Les imports TypeScript devraient être statiques et l’exécution de fonctions utilisateur ne devrait pas être nécessaire pour découvrir la configuration.

### 5.3 IR indépendante de l’AST TypeScript

L’IR devrait conserver :

1. le genre de nœud Nix (`literal`, `path`, `attrset`, `list`, `lambda`, `call`, `select`, `if`, `assert`, `import`, interpolation) ;
2. le nom de clé sous forme de chaîne non échappée, afin de centraliser l’encodage ;
3. le contexte de compilation (`nixos`, `home-manager`, `flake-parts`, expression simple) ;
4. les positions source et l’origine du fichier généré ;
5. les informations de priorité/condition et l’axe `system` ;
6. les références externes (`pkgs`, `lib`, `inputs`, `config`, `options`) comme symboles typés, non comme chaînes ordinaires.

Une seconde couche, distincte des expressions, peut modéliser `NixModule` et `NixFlake`. Cela évite de traiter un module comme un attrset de données alors qu’il est une fonction évaluée dans un fixpoint.

### 5.4 Backends et niveaux d’intégration

**Mode A — données générées, recommandé pour un MVP.** Le TypeScript produit un attrset Nix déterministe ; un module Nix écrit à la main le consomme. Cela limite l’interface du compilateur et laisse la composition, les secrets, les imports et les options sensibles dans Nix.

**Mode B — modules générés.** Le TypeScript produit des modules NixOS/Home Manager ou `flake-parts`, avec des imports statiques et des constructeurs de fusion explicites. C’est la cible utile pour automatiser une configuration, mais elle exige une matrice de versions et des tests d’évaluation.

**Mode C — flake complet.** Le TypeScript produit `flake.nix`, les configurations par système et éventuellement des outputs de packaging. Le lockfile reste géré par les commandes Nix. Ce mode doit être réservé à une étape ultérieure, car il combine modules, inputs, systèmes, conventions d’outputs et cycle de vie du lock.

### 5.5 Émission et validation

Le backend devrait :

- produire un texte Nix stable et lisible, avec ordre déterministe lorsque cela ne change pas la sémantique ;
- utiliser une routine unique d’échappement des clés et des chaînes ;
- refuser ou signaler les collisions de chemins d’attributs ;
- produire une source map entre nœuds IR et lignes Nix ;
- passer `nix-instantiate --parse` ou l’équivalent moderne pour la syntaxe ;
- passer `nixfmt` après émission ;
- évaluer des fixtures avec `nix eval`/`nix-instantiate --eval` ;
- exécuter `nix flake check` pour un backend flake ;
- valider les modules avec `lib.evalModules`, `nixosSystem` ou Home Manager, selon la cible.

Les tests de régression devraient couvrir les clés réservées et contenant des tirets, les clés interpolées, chemins relatifs/absolus, chaînes interpolées, attrsets récursifs, fonctions, doublons, imports, `mkIf`, priorités, plusieurs systèmes et la séparation NixOS/Home Manager. Des snapshots du Nix émis sont utiles, mais ils ne remplacent pas l’évaluation avec les versions verrouillées.

### 5.6 Reproductibilité et sécurité

**Inférences.** Le compilateur devrait :

- pinner la version de TypeScript à cause de l’avertissement de stabilité de son Compiler API ;
- pinner les versions Nixpkgs, NixOS, Home Manager et `flake-parts` contre lesquelles il connaît les options ;
- ne pas modifier silencieusement `flake.lock` ;
- ne pas incorporer de secrets dans les littéraux générés ;
- rendre visible le Nix produit pour revue et diff ;
- traiter les builtins, imports et chemins comme une frontière d’évaluation Nix, pas comme des effets exécutés pendant le build TypeScript.

## 6. Niveau de difficulté

Les niveaux ci-dessous sont des **estimations inférées** des contraintes documentées, pas des mesures de projet.

| Sous-problème | Difficulté | Pourquoi |
| --- | ---: | --- |
| Records/listes/valeurs simples → Nix | 2/5 | Émission directe possible, à condition de gérer l’échappement et la distinction chaîne/chemin |
| Expressions avec références, fonctions, imports et chemins | 3/5 | L’IR doit représenter une sémantique Nix, pas seulement des valeurs sérialisables |
| Modules NixOS/Home Manager | 4/5 | Fixpoint, imports statiques, types d’options, priorités, assertions et contextes de paquets |
| Modules `flake-parts` et outputs multi-systèmes | 4/5 | Il faut modéliser les options de modules et l’axe `system` de la version ciblée |
| Flake complet et cycle du lockfile | 4–5/5 | Inputs, outputs conventionnels, systèmes, évaluation et verrouillage sont plusieurs contrats imbriqués |
| TypeScript arbitraire → Nix arbitraire équivalent | 5/5 | Les modèles d’exécution et les types n’ont pas de correspondance générale documentée ; une restriction ou un runtime serait nécessaire |

**Verdict.**

- Pour un générateur de configuration typé, la faisabilité est **bonne**.
- Pour un compilateur de modules ciblés, elle est **bonne mais coûteuse**, avec un risque élevé de compatibilité entre versions.
- Pour un transpileur général TypeScript → Nix, elle est **très faible comme objectif raisonnable** ; le bénéfice ne compense probablement pas la surface sémantique.

## 7. Points non vérifiés et prochaines validations nécessaires

1. Le dépôt Nix expose un AST C++ interne, mais aucune promesse de compatibilité d’une API AST publique et stable n’a été vérifiée dans la documentation consultée.
2. La stabilité exacte de la sortie de `nix-instantiate --parse` entre versions n’a pas été vérifiée comme contrat ; elle doit être traitée comme une représentation textuelle de diagnostic.
3. La disponibilité d’un binding JavaScript/TypeScript maintenu pour `rnix-parser` ou `tree-sitter-nix`, ainsi que leur parité avec la version Nix cible, n’a pas été testée.
4. L’extraction automatique d’un schéma complet des options NixOS/Home Manager vers des déclarations TypeScript n’a pas été prototypée ; elle devra gérer types, définitions, priorités, modules conditionnels et versions.
5. Les affirmations de maturité et de couverture de `tnix` n’ont pas été auditées au-delà du contenu de son dépôt officiel.
6. La recherche n’est pas un recensement exhaustif de GitHub ; l’absence d’un compilateur général TS → Nix dans la liste ne constitue pas une preuve d’absence.
7. Les noms et APIs précis de `flake-parts`, NixOS et Home Manager devront être testés contre le `flake.lock` du projet consommateur.
8. Aucun prototype de compiler ni build d’intégration n’a été exécuté pour ce brouillon. Des smoke tests locaux ont toutefois vérifié le parsing d’une lambda/attrset et la sérialisation JSON de valeurs simples avec Nix 2.34.8 ; la prochaine étape utile reste un prototype Mode A avec une dizaine de fixtures d’échappement, puis un module NixOS/Home Manager minimal.

## 8. Sources primaires consultées

### Nix : langage, parseur et CLI

- [Nix — syntaxe du langage](https://nix.dev/manual/nix/2.35/language/syntax.html)
- [Nix — évaluation](https://nix.dev/manual/nix/2.35/language/evaluation.html)
- [Nix — types](https://nix.dev/manual/nix/2.35/language/types.html)
- [Nix — portée](https://nix.dev/manual/nix/2.35/language/scope.html)
- [Nix — identifiants et variables](https://nix.dev/manual/nix/2.35/language/identifiers.html)
- [Nix — constructions](https://nix.dev/manual/nix/2.35/language/constructs.html)
- [Nix — opérateurs](https://nix.dev/manual/nix/2.35/language/operators.html)
- [Nix — littéraux de chaînes](https://nix.dev/manual/nix/2.35/language/string-literals.html)
- [Nix — interpolation de chaînes](https://nix.dev/manual/nix/2.35/language/string-interpolation.html)
- [Nix — contexte de chaînes](https://nix.dev/manual/nix/2.35/language/string-context.html)
- [Nix — derivations](https://nix.dev/manual/nix/2.35/language/derivations.html)
- [Nix — attributs avancés](https://nix.dev/manual/nix/2.35/language/advanced-attributes.html)
- [Nix — Import From Derivation](https://nix.dev/manual/nix/2.35/language/import-from-derivation.html)
- [Nix — `nix-instantiate`](https://nix.dev/manual/nix/2.35/command-ref/nix-instantiate)
- [Nix — grammaire `parser.y`](https://github.com/NixOS/nix/blob/master/src/libexpr/parser.y)
- [Nix — lexer `lexer.l`](https://github.com/NixOS/nix/blob/master/src/libexpr/lexer.l)
- [Nix — AST interne `nixexpr.hh`](https://github.com/NixOS/nix/blob/master/src/libexpr/include/nix/expr/nixexpr.hh)
- [Nix — état du parseur `parser-state.hh`](https://github.com/NixOS/nix/blob/master/src/libexpr/include/nix/expr/parser-state.hh)
- [Nix — source de la commande flake](https://github.com/NixOS/nix/blob/master/src/nix/flake.md)
- [Nix — commande `nix flake`](https://nix.dev/manual/nix/2.35/command-ref/new-cli/nix3-flake.html)
- [Nix — concepts des flakes](https://nix.dev/concepts/flakes.html)

### NixOS, nixpkgs et Home Manager

- [Manuel NixOS — écriture de modules](https://nixos.org/manual/nixos/stable/#sec-writing-modules)
- [Manuel NixOS — options](https://nixos.org/manual/nixos/stable/options.html)
- [Manuel nixpkgs — système de modules](https://nixos.org/manual/nixpkgs/unstable/#module-system)
- [nixpkgs — `lib/modules.nix`](https://github.com/NixOS/nixpkgs/blob/master/lib/modules.nix)
- [nixpkgs — `eval-config.nix`](https://github.com/NixOS/nixpkgs/blob/master/nixos/lib/eval-config.nix)
- [nixpkgs — flake d’exemple](https://github.com/NixOS/nixpkgs/blob/master/flake.nix)
- [nixpkgs — générateur de configuration `tools.nix`](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/tools/tools.nix)
- [nixpkgs — `nixos-generate-config.pl`](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/tools/nixos-generate-config.pl)
- [Home Manager — intégration NixOS](https://github.com/nix-community/home-manager/blob/master/docs/manual/installation/nixos.md)
- [Home Manager — modules](https://github.com/nix-community/home-manager/blob/master/modules/modules.nix)
- [Home Manager — module flake](https://github.com/nix-community/home-manager/blob/master/flake-module.nix)
- [flake-parts](https://github.com/hercules-ci/flake-parts)

### Générateurs et langages alternatifs

- [dhall-nix](https://github.com/dhall-lang/dhall-haskell/tree/main/dhall-nix)
- [tnix](https://github.com/ubugeeei-prod/tnix)
- [tnix — architecture](https://github.com/ubugeeei-prod/tnix/blob/main/docs/architecture.md)
- [tnix — référence du langage](https://github.com/ubugeeei-prod/tnix/blob/main/docs/language-reference.md)
- [node2nix](https://github.com/svanderburg/node2nix/blob/master/README.md)
- [dream2nix](https://github.com/nix-community/dream2nix/blob/main/README.md)
- [npmlock2nix](https://github.com/nix-community/npmlock2nix/blob/master/README.md)
- [cabal2nix](https://github.com/NixOS/cabal2nix)
- [Nickel](https://github.com/nickel-lang/nickel)
- [Nix — générateurs de données nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/lib/generators.nix)

### Parsing, AST et outils

- [rnix-parser](https://github.com/nix-community/rnix-parser)
- [tree-sitter-nix](https://github.com/nix-community/tree-sitter-nix)
- [nixfmt](https://github.com/NixOS/nixfmt)
- [nixd](https://github.com/nix-community/nixd)
- [nixd — configuration et inspection des options](https://github.com/nix-community/nixd/blob/main/nixd/docs/configuration.md)
- [hnix](https://github.com/haskell-nix/hnix)

### Frontend TypeScript

- [TypeScript — Using the Compiler API](https://github.com/microsoft/TypeScript/wiki/Using-the-Compiler-API)
- [TypeScript — types de l’API du compilateur](https://github.com/microsoft/TypeScript/blob/main/src/compiler/types.ts)
