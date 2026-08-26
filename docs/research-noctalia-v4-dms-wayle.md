# Comparaison exhaustive — Noctalia v4, DankMaterialShell et Wayle

Date de vérification : 2026-08-26  
Périmètre : arbres et documentations officielles visibles à cette date, avec un
focus sur Wayland/Niri et NixOS.

## Verdict

Noctalia v4 et DankMaterialShell sont des shells complets. Wayle est un shell
plus léger centré sur une barre, ses menus déroulants et les contrôles système.
Wayle est bien compatible avec Niri, mais il ne remplace pas Noctalia v4 à
fonctionnalités constantes : il n'a pas de lanceur, dock, taskbar, historique du
presse-papiers, écran de verrouillage ou système de plugins général intégré.

Pour un remplacement direct, DMS est le candidat le plus complet. Pour une barre
moderne et une configuration TOML propre, Wayle est intéressant si l'on accepte
d'ajouter séparément les composants absents.

## Légende

| Symbole | Signification |
| --- | --- |
| ✓ | Fonction intégrée et documentée dans le projet. |
| ◐ | Fonction partielle, optionnelle, limitée à certains compositeurs ou fournie par une dépendance externe. |
| — | Non fourni par le shell lui-même. |

Une fonction marquée intégrée peut tout de même nécessiter un service système
(NetworkManager, BlueZ, PipeWire, UPower, awww, cliphist, etc.).

## Matrice fonctionnelle

### Architecture et compatibilité

| Fonction | Noctalia v4 | DankMaterialShell (DMS) | Wayle |
| --- | --- | --- | --- |
| Technologie | ✓ Quickshell, Qt 6, QML ; branche v4.7.7 archivée. | ✓ Interface Quickshell/QML + backend Go dms reliés par socket Unix. | ✓ Rust, GTK4, Relm4 et crates de services réactives. |
| Surface Wayland | ✓ Layer-shell via Quickshell pour barres, panneaux, OSD, dock et lock screen. | ✓ Layer-shell, screencopy, output-management, gamma-control, workspace et data-control selon la fonction. | ✓ Requiert un compositeur implémentant wlr-layer-shell. |
| Niri | ✓ Services natifs pour workspaces, fenêtre active, taskbar et adaptations Niri. | ✓ Intégration prioritaire : workspaces, overview, écrans, raccourcis et fichiers Niri. | ✓ Modules niri-workspaces, window-title et source clavier Niri. |
| Hyprland | ✓ Backend natif. | ✓ Backend optimisé avec règles et commandes Hyprland. | ✓ Backend et modules Hyprland, dont hyprsunset. |
| Sway | ✓ Backend natif. | ✓ Supporté, avec moins de fonctions spécifiques. | ◐ Sway annoncé/en développement, pas terminé dans l'arbre vérifié. |
| Scroll | ✓ Backend natif. | ✓ Supporté. | — Aucun backend Scroll dédié. |
| MangoWC/Mango | ✓ Backend natif. | ✓ Backend et tags/workspaces Mango. | ✓ Module Mango/workspaces. |
| Labwc | ✓ Backend natif. | ✓ Supporté, intégration moins riche. | — Aucun backend Labwc dédié. |
| Miracle WM | — Non listé comme backend officiel v4. | ✓ Backend listé officiellement. | — Non listé. |
| Autres compositeurs | ◐ Possibles avec adaptation des workspaces/fenêtres. | ◐ Layer-shell possible, avec fonctions réduites. | — Pas de promesse au-delà des backends listés et layer-shell. |

### Barres et navigation

| Fonction | Noctalia v4 | DankMaterialShell (DMS) | Wayle |
| --- | --- | --- | --- |
| Barre principale | ✓ Haut/bas/gauche/droite, floating, densité, auto-hide et zone d'exclusion. | ✓ DankBar par écran, groupes, popouts et Frame Mode. | ✓ Haut/bas/gauche/droite, sections gauche/centre/droite et layouts par écran. |
| Personnalisation par moniteur | ✓ Overrides de position, widgets et visibilité. | ✓ Configurations de barres, dock et écrans par moniteur. | ✓ Layout ciblé par connecteur, héritage extends et masquage par écran. |
| Workspaces/tags | ✓ Widget Workspace avec service par compositeur. | ✓ Switcher, indicateurs, renommage et actions selon backend. | ✓ Workspaces Niri, Hyprland et Mango, click-to-switch et icônes d'applications. |
| Overview de fenêtres | ◐ Le compositeur fournit l'overview ; v4 peut afficher un fond/overlay Niri, mais ne gère pas le tiling. | ◐ Intégration de l'overview du compositeur ; DankDash fournit aussi un dashboard, pas un WM. | — Aucun overview de fenêtres. |
| Fenêtre active | ✓ Widget ActiveWindow. | ✓ Focused App/Focused Window. | ✓ Module window-title avec titre/app/icône. |
| Liste des fenêtres/taskbar | ✓ Taskbar : fenêtres, épinglés, groupement et menus. | ✓ Running Apps et dock avec groupement/actions. | — Pas de taskbar, seulement la fenêtre active. |
| Dock | ✓ Dock avec épinglés/en cours, indicateurs, groupement, auto-hide et multi-écran. | ✓ Dock, overflow, trash, indicateurs et séparation épinglé/en cours. | — Pas de dock. |
| Lanceur d'applications | ✓ Applications .desktop, catégories, liste/grille, tri par usage. | ✓ Spotlight pour applications et fenêtres. | — Pas de lanceur intégré. |
| Recherche fichiers/URLs | — Pas de moteur fichiers/web v4. | ✓ Fichiers via dsearch, web search et browser picker. | — Pas de moteur intégré. |
| Calculatrice, emojis, commandes | ✓ Providers natifs. | ✓ Providers natifs et extensibles par plugins. | — Un module custom peut lancer une commande, mais ce n'est pas un provider. |
| Panneau de réglages | ✓ Réglages bar, widgets, réseau, médias, thèmes, plugins, wallpaper, etc. | ✓ Réglages très complets et gestion des plugins/thèmes. | ✓ wayle-settings pour shell/modules, pas un panneau de bureau complet. |

### Notifications, panneaux et sessions

| Fonction | Noctalia v4 | DankMaterialShell (DMS) | Wayle |
| --- | --- | --- | --- |
| Notifications popup | ✓ Daemon, urgences, durée, sons, écran et couche configurables. | ✓ Popups, groupement, texte riche, actions et navigation clavier. | ✓ Popups empilées, position/écran/couche/durée/icônes configurables. |
| Historique | ✓ Panneau, suppression et conservation par urgence. | ✓ Centre d'historique, cartes, suppression et groupement. | ✓ Centre avec historique et compteur. |
| DND et règles | ✓ DND, règles, blocklist et IPC. | ✓ DND et règles dans Control Center. | ✓ DND et blocklist par application, moins de règles avancées. |
| Markdown/texte riche | ◐ Markdown v4 optionnel et désactivé par défaut. | ✓ Texte riche/Markdown. | ◐ Notifications standard ; pas de rendu Markdown équivalent documenté. |
| OSD | ✓ Volume, luminosité et changements système. | ✓ Volume/micro, luminosité, média, Caps Lock, idle et profil d'énergie. | ✓ Volume, luminosité et bascules clavier ; surface plus limitée. |
| Control Center/quick settings | ✓ Audio, météo, médias, système, profil et raccourcis réseau/Bluetooth/wallpaper/DND/night light. | ✓ Audio, réseau, Bluetooth, VPN, luminosité, batterie, stockage, imprimantes, DND, couleurs, Tailscale et plugins. | ✓ Dashboard avec Wi-Fi, Bluetooth, mode avion, DND, idle inhibit, économie d'énergie, audio/média/batterie/système. |
| Menu de session | ✓ Lock, suspend, hibernate, reboot, logout, shutdown, reboot UEFI, compte à rebours. | ✓ Lock, suspend, hibernate, reboot, logout, poweroff, switch user et actions custom. | ◐ Lock, logout, reboot et power-off via commandes configurables ; pas de hibernate/suspend UI équivalente documentée. |
| Écran de verrouillage | ✓ Lock screen natif avec PAM, mot de passe, fond, horloge, médias et écrans. | ✓ Lock screen natif, PAM/auth sync et options fingerprint/U2F selon stack. | — Pas de lock screen ; commande externe nécessaire. |
| Inactivité/DPMS | ✓ Idle monitor : screen-off, lock, suspend, fade et commandes custom. | ✓ Idle, auto-lock/suspend, délais AC/batterie, inhibition et DPMS. | ◐ Idle inhibitor uniquement : pas d'auto-lock/DPMS/suspend. |

### Audio, média, réseau et matériel

| Fonction | Noctalia v4 | DankMaterialShell (DMS) | Wayle |
| --- | --- | --- | --- |
| Audio sortie | ✓ PipeWire : volume, mute, périphérique, applications et feedback optionnel. | ✓ PipeWire : sorties, ports, volumes par application, mute et sons. | ✓ Sortie audio PulseAudio/PipeWire-Pulse, volume, mute et périphérique. |
| Microphone/entrée | ✓ Widget, panneau et mute d'entrée. | ✓ Entrée audio et OSD micro. | ✓ Module microphone et entrée dans le dropdown audio. |
| Média MPRIS | ✓ Mini-player, panneau, lecteur préféré et blacklist. | ✓ MPRIS, lecteur préféré, album art, dashboard et Dank Island. | ✓ MPRIS, lecteur actif/priorité et dropdown. |
| Visualiseur | ✓ Cava/spectrum dans bar, média et widgets. | ✓ Cava/visualiseur dans bar, dashboard/Island. | ✓ Module cava avec entrées PipeWire/Pulse/ALSA/JACK/FIFO et styles bars/wave/peaks. |
| Wi-Fi/Ethernet | ✓ Panneau Network et choix des réseaux. | ✓ NetworkManager, iwd, systemd-networkd et hybride. | ✓ NetworkManager, Wi-Fi/Ethernet, réseaux, mot de passe et débit. |
| VPN | ✓ Widget/panneau VPN. | ✓ VPN NetworkManager et Control Center. | — Pas de module VPN natif. |
| Bluetooth | ✓ Activation, appareils, appairage, RSSI optionnel et auto-connect. | ✓ BlueZ, appairage, codecs et détails. | ✓ BlueZ, scan, appairage et gestion des appareils. |
| Luminosité interne | ✓ brightnessctl/backlight, slider et OSD. | ✓ Backlight, LEDs, OSD et CLI dms brightness. | ✓ Backlight interne ; pas de moniteur externe. |
| DDC/I²C externe | ◐ ddcutil optionnel et réglage DDC. | ✓ DDC/I²C dans backend/Control Center si le moniteur le permet. | — Pas de service DDC/I²C. |
| Batterie | ✓ UPower, charge, seuils, notifications et panneau. | ✓ Batterie, seuils, charge, profils, limite de charge et actions AC/batterie. | ✓ UPower et dropdown avec profils d'alimentation. |
| Profils d'alimentation | ✓ power-profiles-daemon, bar/control center. | ✓ Profils, auto power-saver, OSD et batterie. | ✓ Power Saver/Balanced/Performance dans le dashboard si daemon présent. |
| Gestion des écrans | ◐ Multi-écran et overrides, mais pas de panneau de modes/refresh complet. | ✓ Output-management, profils, modes, refresh, scale et identification. | ◐ Layouts, scale et popups par écran ; pas de modes/refresh. |
| Gamma/night light | ✓ wlsunset, température et programmation. | ✓ gamma-control Wayland et night mode. | ◐ hyprsunset pour Hyprland ; pas d'équivalent générique Niri. |
| Polkit | ◐ Dépend d'un agent externe. | ✓ Agent polkit intégré. | — Aucun agent intégré. |
| Imprimantes | — Pas de CUPS core v4. | ✓ CUPS/IPP et jobs dans Control Center. | — Pas de module imprimante. |

### Wallpaper, presse-papiers et outils visuels

| Fonction | Noctalia v4 | DankMaterialShell (DMS) | Wayle |
| --- | --- | --- | --- |
| Wallpaper | ✓ Fichiers, favoris, multi-écran, transitions GPU, rotation et Wallhaven. | ✓ Par écran, transitions, rotation, blurred/live wallpaper et dashboard. | ✓ Moteur awww, transitions, rotation et overrides par écran. |
| Palette depuis wallpaper | ✓ Schemes prédéfinis, clair/sombre et génération de couleurs. | ✓ matugen/dank16 pour palette wallpaper et applications. | ✓ Extraction native + providers Wayle, matugen, pywal, wallust. |
| Thèmes/applications | ✓ JSON, templates TOML, fonts, ratios et génération d'application. | ✓ GTK/Qt/terminal/VS Code/VSCodium, thèmes JSON, icônes et accents. | ✓ TOML, palette/tokens, SCSS/CSS GTK4, icônes et fonts ; application globale selon provider. |
| Presse-papiers/historique | ◐ UI launcher, aperçus texte/images et annotation ; dépend de wl-clipboard + cliphist. | ✓ Historique, images, filtres, recherche, aperçu, actions, CLI et data-control. | — Aucun historique/UI clipboard intégré. |
| Screenshot | ◐ Pas de capture native clairement exposée dans le core v4 ; plugins/commandes externes possibles. | ✓ Région, écran, tous écrans, sortie, fenêtre, dernière région et capture longue ; PNG/JPEG/PPM + fichier/clipboard. | — Aucun outil intégré. |
| Annotation | ◐ Commande externe depuis l'historique clipboard (Satty/Gradia, etc.). | ◐ Pipe vers Swappy/Satty ; éditeur externe. | — Outil externe via commande custom. |
| Enregistrement | ◐ gpu-screen-recorder est crédité, mais aucun recorder complet n'est exposé par le core v4 ; plugin/commande externe. | — Pas de recorder intégré documenté. | — Pas de recorder intégré. |
| QR code | — Pas de générateur core v4 documenté. | ✓ QR texte/Wi-Fi, copie et PNG. | — Pas de générateur intégré. |
| Widgets desktop | ✓ Horloge, média, météo, stats, audio visualizer, positionnement par écran. | ✓ Horloge/système natifs et widgets de plugins, position/taille persistantes. | — Pas de desktop widgets. |
| Systray | ✓ StatusNotifier et menu contextuel. | ✓ System tray et menus. | ✓ StatusNotifier, blacklist, overrides et échelle. |
| Calendrier | ✓ Mois, événements via Evolution Data Server ou khal selon configuration. | ✓ Dashboard ; DankCalendar synchronise Local, Google, Microsoft, CalDAV et iCloud ; khal possible. | ✓ Calendrier mensuel dans clock ; pas de synchro d'événements documentée. |
| Météo | ✓ Service, carte, effets et localisation. | ✓ Widget, dashboard et Dank Island. | ✓ Conditions + prévisions horaires/journalières ; Open-Meteo, Visual Crossing ou WeatherAPI. |
| File manager/udisks | — Hors périmètre. | — Peut chercher/lancer des fichiers, mais ne remplace pas un file manager. | — Hors périmètre. |

### Monitoring, accessibilité et personnalisation

| Fonction | Noctalia v4 | DankMaterialShell (DMS) | Wayle |
| --- | --- | --- | --- |
| Monitoring système | ✓ CPU, RAM, températures, GPU optionnel, disque, batterie, panneau/widgets. | ✓ CPU/RAM/GPU/temp/disques/processus via dms/dgop, avec recherche/gestion. | ✓ CPU, RAM, stockage, débit réseau et températures ; pas de module GPU officiel vérifié. |
| Clavier/layout | ✓ Layout, lock keys, capture de raccourcis et traductions. | ✓ Layout, Caps Lock, cheatsheets et keybinds. | ✓ Layout, alias, keybind mode et OSD lock keys. |
| Internationalisation | ✓ Nombreuses traductions et langue réglable. | ✓ Traductions, typographie et fonts. | ✓ Locales Fluent, dont français, fonts et scale. |
| HiDPI/multi-monitor | ✓ Ratio général, fonts, overrides par écran. | ✓ Multi-monitor, scale et fractional scaling pour les UIs concernées. | ✓ Layouts par moniteur et facteur de scale 0,25–3,0. |
| Réduction de mouvement | ◐ Animation désactivable, blur/shadows configurables. | ◐ Reduced motion, contraste/typographie et réglages visuels. | ◐ Scale/contraste/palette GTK ; pas de lecteur d'écran. |
| Sons système | ✓ Notifications, timer et feedback volume optionnel. | ✓ Notifications, volume et événements. | — Pas de banque de sons système équivalente documentée. |
| Browser/file picker | — Pas de browser picker v4. | ✓ dms open avec choix navigateur/app et associations MIME. | — Associations système externes. |

### Plugins, configuration et distribution

| Fonction | Noctalia v4 | DankMaterialShell (DMS) | Wayle |
| --- | --- | --- | --- |
| Plugins | ✓ QML + manifest.json, registry, dépôts custom, bar/desktop/panel/launcher/settings. | ✓ QML + plugin.json, registry, bar, Control Center, launcher, daemon, desktop et composite. | — Pas d'API/registry général ; modules shell-backed/SCSS/icons custom. |
| Sécurité des plugins | ◐ Code QML de confiance, sans sandbox ; registry v4 legacy. | ◐ Code QML de confiance ; permissions déclarées ne sont pas une sandbox complète. | ◐ Surface plus petite : commandes shell custom, elles aussi à vérifier. |
| Registry/reproductibilité | ◐ Registry GUI v4, pas de lockfile moderne. | ✓ Registry officiel/custom et plugins.lock.json avec commits exacts. | — Pas de registry de plugins. |
| IPC | ✓ qs ipc call : bar, settings, launcher, calendrier, notifications, wallpaper, médias, plugins, etc. | ✓ IPC JSON sur socket Unix, targets nombreux et keybinds. | ✓ CLI + D-Bus com.wayle.Shell1 ; API plus petite. |
| CLI | ◐ IPC, commandes configurables et hooks. | ✓ run/restart, IPC, plugins, brightness, screenshot, clipboard, QR, color picker, updates, doctor, process, backup, setup. | ✓ panel, config, audio, media, idle et complétions shell. |
| Fichiers de config | ✓ settings.json, colors.json, plugins.json, settings plugins, templates TOML. | ✓ settings/état/thèmes/plugins JSON, GUI et fichiers compositor. | ✓ config.toml, imports, runtime.toml, JSON Schema, GUI et CLI. |
| Hot reload | ✓ Réglages/QML réactifs ; reload/restart pour certains manifests/plugins. | ◐ Réglages souvent réactifs ; registry/plugins nécessitent parfois restart. | ✓ Reload in-process, état valide conservé si le nouveau TOML est invalide. |
| NixOS/Home Manager | ✓ Package, module NixOS et module HM upstream. | ✓ Modules NixOS/HM upstream ; docs indiquent une présence nixpkgs stable. | ✓ pkgs.wayle et services.wayle HM ; docs ciblent unstable/25.11 ou plus récent. |
| Installation | ◐ Flake/Nix et packages communautaires. | ✓ dankinstall + paquets Arch, Fedora, Debian/Ubuntu, openSUSE, Gentoo, Void et Nix. | ✓ Arch, Debian/Ubuntu, Fedora, compilation Cargo et NixOS. |
| Dépendances | Quickshell/noctalia-qs, Qt6, brightnessctl, wl-clipboard, cliphist, ddcutil, wlsunset, wlr-randr, ImageMagick, Python ; calendrier/recording optionnels. | Quickshell, Go dms, PipeWire, BlueZ, NetworkManager/iwd/networkd, matugen, cliphist, dsearch, dgop ; calendrier/screenshot selon options. | GTK4, gtk4-layer-shell, GtkSourceView, libpulse, PipeWire, fftw3, libudev ; BlueZ, NetworkManager, UPower, power-profiles-daemon, awww/providers de thèmes. |
| Architecture/performance | ✓ QML/Qt GPU et plusieurs scripts ; pas de benchmark officiel comparable. | ◐ Très complet mais plus lourd : backend Go + Quickshell + services optionnels ; outil doctor. | ✓ Binaire Rust/GTK4 plus simple et réactif, au prix de moins de surfaces. |
| Maturité | ◐ v4.7.7 stable mais figée ; développement déplacé vers Noctalia v5. | ✓ Projet actif et très fourni ; docs 1.5, arbre de développement 1.6-beta. | ◐ Projet actif, version Cargo 0.7.0 dans l'arbre vérifié, mais écosystème jeune et backend Sway en développement. |

## Recommandation pour Niri/NixOS

1. **DMS** est le remplacement à tester en premier si l'objectif est un shell
   complet : intégration Niri, modules NixOS/Home Manager, screenshot, clipboard,
   écran, CUPS/polkit et plugins.
2. **Wayle** est à tester si l'objectif est surtout une barre légère, déclarative
   et facilement rechargée. Prévoir un launcher, un dock, un lock screen,
   cliphist, screenshots et éventuellement notifications/idle séparés.
3. **Noctalia v4** peut rester la référence fonctionnelle, mais sa branche et son
   registry sont legacy. Il vaut mieux ne plus développer de nouveaux plugins v4
   si une migration vers Noctalia v5 est envisagée.

## Sources primaires

### Noctalia v4

- [Dépôt v4.7.7](https://github.com/noctalia-dev/noctalia-shell/tree/v4.7.7) — README, compositeurs et périmètre.
- [Défauts de configuration v4](https://github.com/noctalia-dev/noctalia-shell/blob/v4.7.7/Assets/settings-default.json) — bar, launcher, dock, notifications, idle, wallpaper, audio, calendrier et plugins.
- [Modules v4](https://github.com/noctalia-dev/noctalia-shell/tree/v4.7.7/Modules) et [services v4](https://github.com/noctalia-dev/noctalia-shell/tree/v4.7.7/Services) — surfaces réellement présentes.
- [Registry officiel legacy v4](https://github.com/noctalia-dev/legacy-v4-plugins) — format QML/manifest.json.
- [Documentation v4 archivée](https://docs.noctalia.dev/noctalia-shell/) — statut legacy de la branche Quickshell.

### DankMaterialShell

- [Dépôt DMS](https://github.com/AvengeMedia/DankMaterialShell) — README, architecture, compositeurs et modules.
- [Vue d'ensemble/architecture](https://danklinux.com/docs/dankmaterialshell/overview/) — intégrations et séparation Go/Quickshell.
- [Compositors](https://danklinux.com/docs/dankmaterialshell/compositors/) — Niri, Hyprland, Sway, MangoWC, labwc, Scroll, Miracle WM.
- [Plugins](https://danklinux.com/docs/dankmaterialshell/plugins-overview/) — registry, surfaces et lockfile.
- [IPC](https://danklinux.com/docs/dankmaterialshell/keybinds-ipc/) — commandes IPC.
- [Screenshot](https://danklinux.com/docs/dankmaterialshell/cli-screenshot/) — captures et pipe vers annotation.
- [NixOS/Home Manager](https://danklinux.com/docs/dankmaterialshell/nixos-flake/) — modules et paquet nixpkgs.
- [Calendrier](https://danklinux.com/docs/dankmaterialshell/calendar-integration/) — khal et DankCalendar.

### Wayle

- [Dépôt Wayle](https://github.com/wayle-rs/wayle) — README, backends et dépendances.
- [Getting started](https://wayle.app/guide/getting-started) — layer-shell, Niri/Hyprland/Mango, services.
- [Configuration et hot reload](https://wayle.app/guide/editing-config) — TOML, imports, runtime, GUI et CLI.
- [Barres/layouts](https://wayle.app/guide/bars-and-layouts) — per-monitor et modules custom.
- [Référence des modules](https://wayle.app/config/) — liste complète des modules.
- [Wallpaper](https://wayle.app/config/wallpaper), [styling](https://wayle.app/config/styling) et [OSD](https://wayle.app/config/osd).
- [NixOS/Home Manager](https://wayle.app/guide/getting-started-nixos) — pkgs.wayle et services.wayle.
- [Crates de services](https://github.com/wayle-rs/wayle-services) — audio, batterie, Bluetooth, réseau, média, systray, wallpaper et météo.

## Caveats

- Une fonction Niri peut dépendre de la version de Niri et des protocoles
  workspace, screencopy, output-management ou layer-shell.
- Un bouton de session Wayle ne constitue pas un écran de verrouillage : il
  appelle une commande et un verrouilleur externe reste nécessaire.
- Les trois projets exécutent des plugins/scripts/commandes avec les droits de la
  session utilisateur ; vérifier le code avant installation.
- Les numéros de versions ne sont pas comparables : v4.7.7 est une branche
  legacy, DMS utilise sa propre numérotation et Wayle est encore en 0.x.
