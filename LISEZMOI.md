[English](README.md)

# Utilitaires Portage pour grappes de calcul

Ce repo rassemble des scripts qui servent à faciliter la parallélisation de
tâches sur une grappe de calcul ou sur une machine multi-coeurs. Ces scripts
proviennent à l'origine du project de traduction automatique statistique
Portage, mais ils ont été séparés ici parce qu'il sont d'utilité plus générale.

## Installation

La méthode d'installation la plus simple est d'activer les scripts en place à
partir d'un clone Git:

```sh
git clone https://github.com/nrc-cnrc/PortageClusterUtils.git
```

ajouter ensuite cette ligne à votre .profile ou .bashrc:

```
source /path/to/PortageClusterUtils/SETUP.bash
```

Si vous préférez, vous pouvez aussi installer ces scripts à la destination de
votre choix ainsi:

```sh
cd bin/
make install INSTALL_DIR=/destination/de/votre/choix
```

ce qui copiera les scripts dans `/destination/de/votre/choix/bin/`.
La destination par défaut est `$HOME/bin`.

## Utilisation (en anglais seulement)

### Scripts principaux

The outils principaux fournis par ce repo sont les suivants:

 - parallelize.pl: paralléliser un programme de type pipeline.

 - run-parallel.sh: exécuter un nombre de commandes indépendances en parallèle.

 - psub: encapsuler les spécificité d'un cluster à l'autre à un seul endroit.

Voir [Main Scripts (en anglais)](README.md#Main-Scripts) pour plus de détails.

### Autres Scripts

Voir [Other Scripts (en anglais)](README.md#Other-Scripts) pour la liste.

## Citation

```bib
@misc{Portage_Cluster_Utils,
author = {Joanis, Eric and Stewart, Darlene and Larkin, Samuel and Leger, Serge},
license = {MIT},
title = {{Portage Cluster Utils}},
url = {https://github.com/nrc-cnrc/PortageClusterUtils}
year = {2022},
}
```

## Copyright

Traitement multilingue de textes / Multilingual Text Processing \
Centre de recherche en technologies numériques / Digital Technologies Research Centre \
Conseil national de recherches Canada / National Research Council Canada \
Copyright 2022, Sa Majesté le Roi du Chef du Canada / His Majesty the King in Right of Canada \
Publié sous la license MIT (voir [LICENSE](LICENSE))
