# EasyEffects : profils et configuration déclarative

Recherche du 23 octobre 2026. Aucun changement de configuration ni activation effectué.

## Faisabilité

Oui : le Home Manager déjà épinglé dans `flake.lock`
(`6750249c69969d09d952efaf3fab88a2bdac7ec6`) propose les options nécessaires.
Son module EasyEffects est identique à celui de `master` consulté ce jour.

- `services.easyeffects.extraPresets.<nom>.input/output` génère les profils JSON.
- `services.easyeffects.preset = { input = "Microphone"; output = "Music Ducking"; };`
  sélectionne les profils au démarrage, indépendamment, avec EasyEffects ≥ 8.0.9.
  Le chargement attend le socket local après le démarrage du service.
- `services.easyeffects.settings.<groupe>.<clé>` applique les réglages globaux
  EasyEffects ≥ 8.0 : booléens, nombres, chaînes, chemins ; `null` supprime une clé.
  Le fichier KConfig reste modifiable : `kwriteconfig6` écrit uniquement les clés
  déclarées, avant chaque démarrage du service. Ces valeurs ne sont donc pas
  imposées en continu pendant l'utilisation.
- `services.easyeffects.enable` installe un service utilisateur avec redémarrage
  après échec. Ces options sont conditionnées à son activation.

Source : [module Home Manager épinglé](https://github.com/nix-community/home-manager/blob/6750249c69969d09d952efaf3fab88a2bdac7ec6/modules/services/easyeffects.nix).

## Forme recommandée pour ce dépôt

Conserver les exports JSON complets dans `modules/easyeffects/assets/`, puis importer
leur contenu. Le module Home Manager ajoute lui-même l'enveloppe `input`/`output` :

```nix
services.easyeffects = {
  enable = true;
  extraPresets."Music Ducking".output =
    (builtins.fromJSON (builtins.readFile ./assets/music-ducking.json)).output;
  extraPresets."Without Music Ducking".output =
    (builtins.fromJSON (builtins.readFile ./assets/without-music-ducking.json)).output;
};
```

Les réglages globaux peuvent fixer les périphériques d'entrée/sortie ou les
préférences voulues. Les compteurs d'utilisation, dimensions de fenêtre et pages
visibles peuvent rester locaux. `settings` cible seulement
`easyeffects/db/easyeffectsrc`, pas les bases `compressorrc`, `rnnoiserc`, etc.
[Implémentation Home Manager](https://github.com/nix-community/home-manager/blob/6750249c69969d09d952efaf3fab88a2bdac7ec6/modules/services/easyeffects.nix).

## Inventaire local avant l'export micro et précautions de migration

Constats locaux, distincts de la documentation amont :

- Deux profils sauvegardés dans `~/.local/share/easyeffects/output/` :
  `Music Ducking.json` et `Without Music Ducking.json`, chacun avec `compressor#0`.
- Aucun profil d'entrée sauvegardé, alors que la chaîne micro active contient
  `rnnoise#0`, `filter#0`, `gate#0` et `compressor#0`.
- Aucun autoload, modèle RNNoise externe ni réponse impulsionnelle présent dans
  les répertoires correspondants examinés.
- Le démarrage actuel passe par un fichier XDG autostart ; il faudra choisir le
  service Home Manager comme propriétaire du démarrage et désactiver cet autostart.

Il faut donc **sauvegarder la chaîne micro actuelle comme profil avant migration**.
La sauvegarde native inclut l'ordre des effets et leurs paramètres : conserver
seulement `StreamInputs.plugins` ne sauvegarderait pas les réglages des effets.
[Sauvegarde native des profils](https://github.com/wwmm/easyeffects/blob/master/src/presets_manager.cpp).

Les profils gérés par Home Manager sont des fichiers du Nix store : les charger et
ajuster les effets en mémoire reste possible, mais sauvegarder par-dessus ces
profils depuis l'interface échouera, car EasyEffects écrit directement dans leur
fichier. Pour expérimenter, utiliser un profil temporaire modifiable, puis importer
son export JSON dans le dépôt.
[Écriture native des profils](https://github.com/wwmm/easyeffects/blob/master/src/presets_manager.cpp).

## Autoload éventuel

EasyEffects 8 place profils, autoloads et ressources dans ses données XDG.
[Gestion des répertoires](https://github.com/wwmm/easyeffects/blob/master/src/presets_directory_manager.cpp).

Home Manager ne propose pas d'option dédiée aux autoloads dans le module examiné.
On peut les gérer via `xdg.dataFile`, sous
`easyeffects/autoload/<input|output>/<device>:<route>.json` : le document contient
`device`, `device-description`, `device-profile` et `preset-name`. Ils ne sont pas
nécessaires pour les deux profils actuels et le bouton Dux.
[Format et sélection des autoloads](https://github.com/wwmm/easyeffects/blob/master/src/presets_autoload_manager.cpp).

## Mise en œuvre

Le profil `Basic microphone chain` a depuis été sauvegardé et vérifié : il contient
les quatre effets et leurs paramètres. Les trois exports sont intégrés dans
[`modules/easyeffects`](../../modules/easyeffects/README.md), avec le service Home
Manager, les périphériques USB et le chargement des profils au démarrage.
La source du sidechain externe (`communication_sink.capture`), absente des
exports, est fusionnée séparément dans `compressorrc` avant le démarrage.
