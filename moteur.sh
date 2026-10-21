#!/usr/bin/env bash
# Le moteur d'analyse, livré dans l'app et jamais téléchargé par elle (règle
# moteur-stockfish). Rien de ce que ce script télécharge ou produit ne se
# commite : les binaires et les .wasm dépassent la limite de 100 Mo de GitHub.
# Une cible par plateforme : un build iOS ne touche à rien d'Android, et
# inversement.
#
# Usage : scripts/moteur.sh android <dossier du NDK>   (ou ANDROID_NDK_ROOT)
#         scripts/moteur.sh ios [<dossier .../moteur>]
#         scripts/moteur.sh sources <dossier absent ou vide>
#
# Une empreinte fausse, une compilation échouée ou un binaire mal aligné font
# échouer le build plutôt que de livrer un moteur douteux.
#
# --- android ---------------------------------------------------------------
#
# Stockfish 18, compilé par nous depuis les sources officielles de la release
# sf_18, non modifiées, et livré dans l'APK sous le nom libstockfish.so.
#
# Pourquoi compiler plutôt que livrer le binaire officiel : celui-ci aligne
# ses segments sur des pages de 4 Ko et plante au lancement (Segmentation
# fault) sur les téléphones à pages de 16 Ko (Android 15 et plus), que Google
# Play exige de prendre en charge (MOT-18). Seuls des drapeaux de compilation
# et d'édition de liens changent : aucune ligne des sources n'est touchée.
#
# Une fois : télécharger l'archive officielle et les deux réseaux NNUE, et
# vérifier leur empreinte SHA-256 complète. Puis, pour chaque ABI : compiler
# avec le NDK, vérifier que chaque segment LOAD est aligné sur 16 Ko, retirer
# les symboles, et poser le binaire (~114 Mo) dans
# android/app/src/main/jniLibs/<abi>/libstockfish.so de façon atomique. Gradle
# lance ce script avant le build (android/app/build.gradle.kts) ; le relancer
# ne refait rien si les sources, les réseaux, les drapeaux et le NDK n'ont pas
# changé.
#
# Le cache .cache/moteur/sf_18/ garde l'archive : elle porte les sources
# exactes (src/) et la licence (Copying.txt) du binaire livré (MOT-07).
#
# --- ios -------------------------------------------------------------------
#
# Stockfish.js 18, le build WebAssembly de Stockfish 18 par Chess.com (GPL
# v3), tel que publié, en deux éditions : multi-thread, et mono-thread pour
# une page qui ne serait pas isolée (sans SharedArrayBuffer). Ses réseaux NNUE
# sont embarqués dans le .wasm.
#
# Télécharger les quatre fichiers dans .cache/moteur/stockfish.js-<version>/,
# vérifier leur empreinte SHA-256, puis les copier, avec la page du moteur
# (ios/moteur/index.html, notre code), dans le dossier de destination. La
# phase « Moteur Stockfish.js » du target Runner (ios/Runner.xcodeproj), qui
# précède la phase Flutter, lui donne Runner.app/moteur/, remplacé en entier.
# Sans destination, le script ne remplit que le cache. Le bundle iOS plutôt que les assets
# Flutter : ceux-ci entreraient aussi dans l'APK (226 Mo pour rien).
#
# --- sources ---------------------------------------------------------------
#
# La « source correspondante » de la GPL v3 de ce que l'app livre (MOT-07),
# dont nous hébergeons une copie sous notre contrôle : la GPL v3 (§6d) exige
# que l'accès reste assuré tant que l'app est distribuée.
#   - Android : l'archive sf_18 (sources src/ et licence), les deux réseaux
#     NNUE, et ce script, qui compile ;
#   - iOS : l'archive du tag de Stockfish.js (sources et build.js), avec les
#     deux mêmes réseaux, que son .wasm embarque.
# Ce sont les fichiers mêmes des cibles android et ios, vérifiés par les
# mêmes empreintes, dans le même cache : jamais une « dernière version »
# prise ailleurs. Ni NDK ni compilation. Le dossier, absent ou vide, reçoit
# ces fichiers, une copie de ce script, SHA256SUMS et index.html, une page
# autonome (anglais puis français) qui dit ce qui est livré et comment le
# reconstruire.
#
# Le script ne publie rien : scripts/publier_sources_moteur.sh assemble la
# copie par cette cible et la publie dans la Release stockfish-<version> du
# dépôt public GitHub Notipro/notichess-stockfish-sources (MOT-26). Une
# Release publiée ne se supprime ni ne se remplace jamais : chaque version
# de l'app distribuée y renvoie. Tout changement du moteur livré (sources,
# réseaux, drapeaux, Stockfish.js) se publie sous une nouvelle version, avec
# l'URL de l'app. Un autre NDK change le binaire, pas la source
# correspondante : il n'en demande pas une nouvelle.
set -euo pipefail

# Monter de version : la release, l'archive, les réseaux (ceux que nomme
# src/evaluate.h) et leurs empreintes changent ensemble, avec
# kBundledEngineVersion (lib/core/engine/engines_manifest.dart, gardé par
# test/core/engine/engine_version_test.dart). Changent aussi :
#   - les années des mentions de copyright de Stockfish et de Stockfish.js,
#     écrites dans lib/core/engine/licence_du_moteur.dart ;
#   - la Release publiée, stockfish-<version> : une nouvelle Release,
#     jamais l'ancienne (voir la cible sources), dont l'URL de l'app,
#     urlDesSourcesDuMoteur (même fichier), tire le nom de
#     kBundledEngineVersion ; les tests qui la vérifient l'écrivent en dur,
#     comme la garde de .github/workflows/cd.yaml.
#
# Provenance des empreintes :
#   - l'archive : le condensé SHA-256 que GitHub publie pour chaque fichier
#     d'une release (gh api repos/official-stockfish/Stockfish/releases/tags/
#     sf_18, champ digest) ;
#   - les réseaux : leur nom porte les 12 premiers caractères de leur
#     empreinte ; l'empreinte complète, de fichiers dont le nom concorde, est
#     écrite ici, car le scripts/net.sh de Stockfish n'en vérifie que ces 12.
readonly VERSION=sf_18
readonly URL_RELEASE="https://github.com/official-stockfish/Stockfish/releases/download/$VERSION"
readonly URL_RESEAUX="https://tests.stockfishchess.org/api/nn"

# N'importe quelle archive Android de la release porte les mêmes sources ;
# son binaire, lui, ne sert pas.
readonly ARCHIVE=stockfish-android-armv8.tar
readonly ARCHIVE_SHA256=e2eca54b0e3189ec7de338133c2b34fa8f5cdec3d2473519b414a5cb6815e768
readonly GRAND_RESEAU=nn-c288c895ea92.nnue
readonly GRAND_RESEAU_SHA256=c288c895ea924429ea9092e3f36b2b3c1f00f2a3a4c759ff7e57e79e3b43e4a7
readonly PETIT_RESEAU=nn-37f18f62d772.nnue
readonly PETIT_RESEAU_SHA256=37f18f62d772f3107e1d6aaca3898c130c3c86f2ab63e6555fbbca20635a899d

# La compilation de la release (.github/workflows/arm_compilation.yml de
# sf_18) : make profile-build ARCH=<arch> COMP=ndk, LDFLAGS="-static ...".
# Nos seuls écarts (le nombre de tâches de make, le seul autre, ne change pas
# le binaire) :
#   - l'alignement 16 Ko, à l'édition de liens ;
#   - KERNEL=Linux : sur un hôte macOS, le Makefile ajouterait sinon
#     -mdynamic-no-pic, que le compilateur Android refuse ;
#   - build au lieu de profile-build : l'optimisation guidée par profil
#     exécute le moteur pendant la compilation, ce que l'hôte ne sait pas
#     faire d'un binaire Android. Seule la vitesse en dépend : la signature
#     de bench du binaire obtenu est celle de la release (2050811).
readonly DRAPEAUX_EDITION="-static -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"

# Stockfish.js : monter de version, c'est changer la release, les noms et les
# empreintes ensemble. Provenance des empreintes : le condensé SHA-256 que
# GitHub publie pour chaque fichier de la release (gh api
# repos/nmrugg/stockfish.js/releases/tags/v18.0.0, champ digest). Les .js du
# paquet npm « stockfish » diffèrent de ceux de la release : seule la release
# fait foi.
readonly VERSION_JS=v18.0.0
readonly URL_JS="https://github.com/nmrugg/stockfish.js/releases/download/$VERSION_JS"
readonly JS_MULTI=stockfish-18.js
readonly JS_MULTI_SHA256=8bce234759d32fa02b27cfca7e58c3816c9729733910c304df057a169fb755e1
readonly WASM_MULTI=stockfish-18.wasm
readonly WASM_MULTI_SHA256=8bef136a3d7a428b5cbc624459a2091fd3e750c22a48dad9ad3b292ac80373cb
readonly JS_MONO=stockfish-18-single.js
readonly JS_MONO_SHA256=0c745dded6825d54a925095aa2698b38d95895b02e4c3560e9dc4e2af36163af
readonly WASM_MONO=stockfish-18-single.wasm
readonly WASM_MONO_SHA256=f611ac05ddb248fe975a4f180ac9fec7f7fb650f8f17f5fe4230fcc0fe6419c7

# Les sources de cette release : l'archive que GitHub génère pour son tag,
# publiée sous ce nom. Son empreinte est calculée par nous (2026-10-03,
# 583 402 octets) : GitHub n'en publie aucune, et ne garantit pas que
# l'archive reste identique octet pour octet.
readonly URL_ARCHIVE_JS="https://github.com/nmrugg/stockfish.js/archive/refs/tags/$VERSION_JS.tar.gz"
readonly ARCHIVE_JS=stockfish.js-v18.0.0.tar.gz
readonly ARCHIVE_JS_SHA256=04ab07ed29bdf4393187eb6f73bdf0f9d422168050f326cec039f87fac2121cb

racine=$(cd "$(dirname "$0")/.." && pwd)
jnilibs="$racine/android/app/src/main/jniLibs"
# Le make qui compile le moteur : sous Windows, choisi par preparer_windows.
make=make
# Le cache de la cible, posé par cible_android ou cible_ios.
cache=

empreinte() { shasum -a 256 "${1:--}" | cut -d' ' -f1; }

# telecharger <url> <empreinte attendue> [<nom> [<remarque>]] : vers le
# cache, une seule fois, sous <nom> (par défaut, celui de l'URL). La
# remarque s'ajoute au message d'une empreinte inattendue.
telecharger() {
  local url=$1 attendue=$2 nom=${3:-${1##*/}} remarque=${4:-}
  local fichier="$cache/$nom"
  [ -f "$fichier" ] && [ "$(empreinte "$fichier")" = "$attendue" ] && return
  mkdir -p "$cache"
  echo "moteur : téléchargement de $url"
  curl -fsSL --retry 3 -o "$fichier.part" "$url"
  local obtenue
  obtenue=$(empreinte "$fichier.part")
  if [ "$obtenue" != "$attendue" ]; then
    rm -f "$fichier.part"
    echo "moteur : empreinte SHA-256 inattendue pour $nom, rien n'est installé." >&2
    echo "  attendue : $attendue" >&2
    echo "  obtenue  : $obtenue" >&2
    [ -z "$remarque" ] || echo "  $remarque" >&2
    exit 1
  fi
  mv "$fichier.part" "$fichier"
}

sources_pretes=
preparer_sources() {
  [ -n "$sources_pretes" ] && return
  telecharger "$URL_RELEASE/$ARCHIVE" "$ARCHIVE_SHA256"
  telecharger "$URL_RESEAUX/$GRAND_RESEAU" "$GRAND_RESEAU_SHA256"
  telecharger "$URL_RESEAUX/$PETIT_RESEAU" "$PETIT_RESEAU_SHA256"
  sources_pretes=1
}

# Chaque segment LOAD doit avoir un alignement multiple de 16 Ko, et un
# décalage dans le fichier congru à son adresse modulo 16 Ko : c'est ce que
# le chargeur d'un système à pages de 16 Ko exige. Aucun segment : refus.
verifier_alignement() {
  local binaire=$1 segments=0 type decalage adresse _p _f _m reste alignement
  local description
  description=$(llvm-readelf -lW "$binaire")
  while read -r type decalage adresse _p _f _m reste; do
    [ "$type" = LOAD ] || continue
    alignement=${reste##* }
    # Écrit dans ce sens, un champ illisible compte comme mal aligné.
    if ! (( alignement % 16384 == 0 && decalage % 16384 == adresse % 16384 )); then
      echo "moteur : $binaire n'est pas aligné sur 16 Ko, rien n'est installé." >&2
      echo "  LOAD $decalage $adresse, alignement $alignement" >&2
      exit 1
    fi
    segments=$((segments + 1))
  done <<< "$description"
  if [ "$segments" -eq 0 ]; then
    echo "moteur : aucun segment LOAD lu dans $binaire, rien n'est installé." >&2
    exit 1
  fi
}

# compiler <abi Android> <ARCH du Makefile de Stockfish>
compiler() {
  local abi=$1 arch=$2
  local cible="$jnilibs/$abi/libstockfish.so"
  local trace="$cache/$abi.empreinte"

  # Les entrées : ce script (version, empreintes, drapeaux) et le NDK.
  local entrees
  entrees=$({ cat "${BASH_SOURCE[0]}" "$ndk/source.properties"; echo "$abi"; } | empreinte)
  if [ -f "$cible" ] && [ -f "$trace" ] &&
    [ "$(cat "$trace")" = "$entrees $(empreinte "$cible")" ]; then
    return
  fi

  preparer_sources
  local dossier="$construction/$abi"
  mkdir "$dossier"
  tar -xf "$cache/$ARCHIVE" -C "$dossier" stockfish/src stockfish/scripts
  cp "$cache/$GRAND_RESEAU" "$cache/$PETIT_RESEAU" "$dossier/stockfish/src/"

  echo "moteur : compilation de $abi (ARCH=$arch, $VERSION)"
  # Le Makefile de Stockfish ajoute à ses drapeaux CXXFLAGS, LDFLAGS,
  # DEPENDFLAGS et EXTRACXXFLAGS du poste, et prend COMPCXX pour compilateur :
  # le binaire ne doit dépendre que de ce script et du NDK.
  if ! (cd "$dossier/stockfish/src" &&
    env -u CXXFLAGS -u LDFLAGS -u DEPENDFLAGS -u EXTRACXXFLAGS -u COMPCXX \
      "$make" -j"$taches" build ARCH="$arch" COMP=ndk KERNEL=Linux \
      EXTRALDFLAGS="$DRAPEAUX_EDITION") > "$dossier/make.log" 2>&1; then
    cat "$dossier/make.log" >&2
    echo "moteur : la compilation de $abi a échoué, rien n'est installé." >&2
    exit 1
  fi
  local binaire="$dossier/stockfish/src/stockfish"
  llvm-strip "$binaire"
  verifier_alignement "$binaire"

  mkdir -p "$(dirname "$cible")"
  cp "$binaire" "$cible.part"
  chmod 755 "$cible.part"
  mv "$cible.part" "$cible"
  echo "$entrees $(empreinte "$cible")" > "$trace"
  rm -rf "$dossier"
  echo "moteur : $abi/libstockfish.so compilé, aligné sur 16 Ko et installé ($VERSION)"
}

# Sous Windows, dans Git Bash (MOT-29). Deux écarts avec macOS et Linux, aucun
# dans la compilation elle-même :
#   - le make doit être celui de MSYS2, POSIX. Le make natif de Windows
#     (MinGW) lance les recettes du Makefile de Stockfish avec cmd.exe et
#     sépare son VPATH par « ; » : « No rule to make target 'tbprobe.o' » ;
#   - le NDK livre ses compilateurs (aarch64-linux-android29-clang++...) en
#     fichiers .cmd, que bash ne lance pas. Un relais de même nom, posé dans
#     le dossier de compilation, fait ce que fait son .cmd : appeler
#     clang++.exe avec la cible que porte le nom.
#
# Le make retenu est le premier make POSIX du PATH, pas le premier make : le
# PATH de la machine, où s'installent les chaînes MinGW, passe sous Windows
# avant celui de l'utilisateur, que seul un administrateur peut réordonner.
preparer_windows() {
  local outils=$1 candidat hote ecartes=()
  make=
  while IFS= read -r candidat; do
    # Un make qui ne sait pas répondre est écarté, pas fatal (set -e).
    hote=$("$candidat" --version 2>/dev/null | sed -n 's/^Built for //p') || true
    case "$hote" in
      *-msys | *-cygwin)
        make=$candidat
        break
        ;;
    esac
    ecartes+=("$candidat, construit pour ${hote:-un hôte inconnu}")
  done < <(type -ap make)
  if [ -z "$make" ]; then
    echo "moteur : sous Windows, il faut le make POSIX de MSYS2, et le PATH n'en a aucun." >&2
    [ ${#ecartes[@]} -eq 0 ] || printf '  écarté : %s\n' "${ecartes[@]}" >&2
    echo "  Le make natif de Windows lance les recettes du Makefile de Stockfish avec cmd.exe." >&2
    echo "  Installation : CLAUDE.md, section « Android sous Windows »." >&2
    exit 1
  fi

  local relais="$construction/relais" cmd nom
  mkdir "$relais"
  for cmd in "$outils"/*-clang++.cmd; do
    [ -f "$cmd" ] || continue
    nom=$(basename "$cmd" .cmd)
    printf '#!/usr/bin/env bash\nexec "%s/clang++.exe" --target=%s "$@"\n' \
      "$outils" "${nom%-clang++}" > "$relais/$nom"
    chmod +x "$relais/$nom"
  done
  export PATH="$relais:$PATH"
}

cible_android() {
  cache="$racine/.cache/moteur/$VERSION"
  ndk=${1:-${ANDROID_NDK_ROOT:-}}
  if [ -z "$ndk" ]; then
    echo "moteur : NDK manquant. Usage : scripts/moteur.sh android <dossier du NDK> (ou ANDROID_NDK_ROOT)." >&2
    exit 1
  fi
  local windows=
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) windows=1 ;;
  esac
  # Gradle, sous Windows, donne le NDK en chemin Windows (C:/...) : lu en
  # chemin POSIX (/c/...), sans quoi son « : » couperait l'entrée du PATH.
  [ -z "$windows" ] || ndk=$(cygpath -u "$ndk")
  local outils
  outils=$(echo "$ndk"/toolchains/llvm/prebuilt/*/bin)
  if [ ! -x "$outils/llvm-readelf" ] || [ ! -f "$ndk/source.properties" ]; then
    echo "moteur : aucun NDK utilisable dans $ndk." >&2
    exit 1
  fi
  # Le compilateur (aarch64-linux-android29-clang++...) et llvm-readelf,
  # llvm-strip : ceux du NDK.
  export PATH="$outils:$PATH"

  # Une tâche de make par cœur. En CI, quatre au plus : dans un conteneur, le
  # système annonce souvent les cœurs de l'hôte, pas ceux qui sont alloués,
  # et chaque compilation de Stockfish demande de la mémoire.
  taches=$(getconf _NPROCESSORS_ONLN)
  if [ -n "${CI:-}" ] && [ "$taches" -gt 4 ]; then
    taches=4
  fi

  # Un dossier de compilation propre à cette exécution : un build lancé en
  # même temps a le sien, que celui-ci ne touche pas. Interrompue, la
  # compilation ne laisse rien derrière elle ; seul un build tué net
  # (SIGKILL) laisse le sien, retiré ici quand il n'a pas bougé depuis plus
  # d'un jour, car plus aucun build n'y travaille.
  mkdir -p "$cache"
  find "$cache" -maxdepth 1 -type d -name 'construction.*' -mmin +1440 \
    -exec rm -rf {} +
  construction=$(mktemp -d "$cache/construction.XXXXXX")
  trap 'rm -rf "$construction"' EXIT
  trap 'exit 1' INT TERM HUP

  [ -z "$windows" ] || preparer_windows "$outils"

  compiler arm64-v8a armv8
  compiler armeabi-v7a armv7-neon
}

cible_ios() {
  cache="$racine/.cache/moteur/stockfish.js-$VERSION_JS"
  local destination=${1:-}
  # La destination est remplacée en entier : le script ne supprime qu'un
  # dossier nommé moteur, jamais un dossier donné par erreur.
  case "$destination" in
    '' | */moteur) ;;
    *)
      echo "moteur : la destination doit être un dossier nommé moteur (Runner.app/moteur), pas $destination." >&2
      exit 1
      ;;
  esac
  telecharger "$URL_JS/$JS_MULTI" "$JS_MULTI_SHA256"
  telecharger "$URL_JS/$WASM_MULTI" "$WASM_MULTI_SHA256"
  telecharger "$URL_JS/$JS_MONO" "$JS_MONO_SHA256"
  telecharger "$URL_JS/$WASM_MONO" "$WASM_MONO_SHA256"
  [ -n "$destination" ] || return 0

  # Copié à côté, puis mis à la place de l'ancien dossier : une copie
  # interrompue ne laisse aucun fichier tronqué dans le bundle, et aucun
  # fichier d'une version précédente n'y reste.
  rm -rf "$destination.part"
  mkdir -p "$destination.part"
  cp "$racine/ios/moteur/index.html" \
    "$cache/$JS_MULTI" "$cache/$WASM_MULTI" \
    "$cache/$JS_MONO" "$cache/$WASM_MONO" \
    "$destination.part/"
  rm -rf "$destination"
  mv "$destination.part" "$destination"
  echo "moteur : Stockfish.js $VERSION_JS vérifié et copié dans $destination"
}

cible_sources() {
  local destination=${1:-}
  if [ -z "$destination" ]; then
    echo "moteur : dossier manquant. Usage : scripts/moteur.sh sources <dossier absent ou vide>" >&2
    exit 1
  fi
  # Rien ne s'écrase ni ne se mélange : le dossier publié est exactement ce
  # que ce script assemble.
  if [ -e "$destination" ] && [ -n "$(ls -A "$destination")" ]; then
    echo "moteur : $destination n'est pas un dossier vide, rien n'est posé." >&2
    exit 1
  fi

  cache="$racine/.cache/moteur/$VERSION"
  preparer_sources
  local cache_android=$cache
  cache="$racine/.cache/moteur/stockfish.js-$VERSION_JS"
  telecharger "$URL_ARCHIVE_JS" "$ARCHIVE_JS_SHA256" "$ARCHIVE_JS" \
    "GitHub génère l'archive d'un tag et ne garantit pas qu'elle reste identique octet pour octet : comparer son contenu au tag $VERSION_JS avant de changer ARCHIVE_JS_SHA256."

  mkdir -p "$destination"
  cp "$cache_android/$ARCHIVE" "$cache_android/$GRAND_RESEAU" \
    "$cache_android/$PETIT_RESEAU" "$cache/$ARCHIVE_JS" "$destination/"
  cp "${BASH_SOURCE[0]}" "$destination/moteur.sh"
  (
    cd "$destination"
    # Sous Windows, le shasum de Git marque chaque nom d'un « * » (mode
    # binaire) : retiré, pour que SHA256SUMS soit celui de la Release publiée,
    # « <empreinte>  <nom> », quel que soit le poste.
    shasum -a 256 "$ARCHIVE" "$GRAND_RESEAU" "$PETIT_RESEAU" "$ARCHIVE_JS" \
      moteur.sh | sed 's/ \*/  /' > SHA256SUMS
    page_des_sources > index.html
  )
  echo "moteur : source correspondante assemblée dans $destination"
}

# ligne <fichier> <description> : une ligne du tableau des fichiers, avec
# l'empreinte que donne SHA256SUMS (lancé dans le dossier des sources).
ligne() {
  echo "<tr><td><a href=\"$1\">$1</a></td><td>$2</td><td><code>$(awk -v f="$1" '$2 == f { print $1 }' SHA256SUMS)</code></td></tr>"
}

# La page des sources : autonome (ni script ni ressource externe), lisible
# dans n'importe quel navigateur. La commande de compilation est celle de
# CREDITS.md, que le test compare.
page_des_sources() {
  cat <<EOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Stockfish 18 in NotiChess: source code</title>
<style>
body { font-family: system-ui, sans-serif; line-height: 1.5; max-width: 52rem; margin: 0 auto; padding: 1rem; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #999; padding: 0.25rem 0.5rem; text-align: start; vertical-align: top; }
td code { word-break: break-all; }
pre { overflow-x: auto; padding: 0.5rem; border: 1px solid #999; }
section + section { margin-top: 3rem; border-top: 1px solid #999; }
</style>
</head>
<body>
<section lang="en">
<h1>Stockfish 18 in NotiChess: source code</h1>
<p>The NotiChess mobile app includes the Stockfish chess engine, free software
licensed under the GNU General Public License, version 3 (GPL v3). The engine
runs as a separate program, with which the app exchanges UCI text commands.
This folder holds the complete corresponding source of the engine shipped in
the app, as the GPL v3 requires. The license text is in each archive
(<code>Copying.txt</code>) and on the licenses page of the app.</p>

<h2>What the app ships</h2>
<ul>
<li><strong>Android</strong>: Stockfish 18, release <code>$VERSION</code> of the
official project (<a href="https://github.com/official-stockfish/Stockfish">github.com/official-stockfish/Stockfish</a>),
compiled by NotiChess from the official sources, without any modification, as
<code>libstockfish.so</code> for <code>arm64-v8a</code> (<code>ARCH=armv8</code>)
and <code>armeabi-v7a</code> (<code>ARCH=armv7-neon</code>). License: GPL v3.</li>
<li><strong>iOS</strong>: Stockfish.js 18, release <code>$VERSION_JS</code> of
<a href="https://github.com/nmrugg/stockfish.js">github.com/nmrugg/stockfish.js</a>
(Chess.com and Nathan Rugg, based on Stockfish): <code>$JS_MULTI</code>,
<code>$WASM_MULTI</code>, <code>$JS_MONO</code> and <code>$WASM_MONO</code>,
as published, without any modification. License: GPL v3.</li>
</ul>
<p>On both platforms, the two NNUE networks below are included in the engine
at compile time, and shipped inside it.</p>

<h2>Files</h2>
<table>
<tr><th>File</th><th>Content</th><th>SHA-256</th></tr>
$(ligne "$ARCHIVE" "Official archive of Stockfish release $VERSION: sources (<code>stockfish/src</code>), license (<code>stockfish/Copying.txt</code>), authors (<code>stockfish/AUTHORS</code>). Its prebuilt binary is not used.")
$(ligne "$GRAND_RESEAU" "Big NNUE network, named in <code>src/evaluate.h</code> of both sources.")
$(ligne "$PETIT_RESEAU" "Small NNUE network, named in <code>src/evaluate.h</code> of both sources.")
$(ligne "$ARCHIVE_JS" "Sources of Stockfish.js 18: the GitHub archive of tag <code>$VERSION_JS</code> (<code>src</code>, <code>build.js</code>, license <code>Copying.txt</code>).")
$(ligne moteur.sh "The NotiChess script that downloads, checks and compiles the Android engine, and copies the iOS engine into the app.")
</table>
<p>To check them: <code>shasum -a 256 -c SHA256SUMS</code>
(<a href="SHA256SUMS">SHA256SUMS</a>).</p>

<h2>Building the Android engine</h2>
<p>Extract <code>stockfish/src</code> and <code>stockfish/scripts</code> from
<code>$ARCHIVE</code> (the Makefile runs <code>../scripts/net.sh</code>), and
copy the two <code>.nnue</code> files into <code>stockfish/src</code>. Then, in
<code>stockfish/src</code>, with
the tools of the Android NDK used by Flutter (<code>flutter.ndkVersion</code>)
on the <code>PATH</code>, for each ABI:</p>
<pre>env -u CXXFLAGS -u LDFLAGS -u DEPENDFLAGS -u EXTRACXXFLAGS -u COMPCXX \\
  make -j&lt;N&gt; build ARCH=&lt;armv8|armv7-neon&gt; COMP=ndk KERNEL=Linux \\
  EXTRALDFLAGS="$DRAPEAUX_EDITION"</pre>
<p>then <code>llvm-strip stockfish</code>. <code>&lt;N&gt;</code> is the number
of parallel jobs, with no effect on the binary. Only compiler and linker flags
differ from the official release build: the 16 KB page alignment required by
Android 15 and Google Play; <code>KERNEL=Linux</code>, without which a macOS
host adds <code>-mdynamic-no-pic</code>; <code>build</code> instead of
<code>profile-build</code>, whose profiling step would run the Android binary
on the host.</p>
<p><code>moteur.sh</code> does all of this: placed in a <code>scripts</code>
folder, <code>scripts/moteur.sh android &lt;NDK folder&gt;</code> checks the
three Stockfish files above, compiles both ABIs and writes each
<code>libstockfish.so</code> under <code>android/app/src/main/jniLibs/</code>.
It downloads these files from their original sources, unless they are already
in <code>.cache/moteur/sf_18/</code>, next to the <code>scripts</code> folder:
put the copies from this page there, and nothing is downloaded.</p>

<h2>Building the iOS engine</h2>
<p>Extract <code>$ARCHIVE_JS</code> and copy the two <code>.nnue</code> files
into its <code>src</code> folder (the build downloads them otherwise). With
Node.js, make and emscripten 3.1.7 installed and on the <code>PATH</code>, run,
in the extracted folder,
<code>./build.js --all --only-single --only-standard</code>
(<code>./build.js --help</code> lists the options; without the two
<code>--only</code> options, the other editions need networks that are not
provided here). It builds, in <code>src</code>, <code>$JS_MULTI</code> and
<code>$WASM_MULTI</code> (multi-threaded), <code>$JS_MONO</code> and
<code>$WASM_MONO</code> (single-threaded), with both networks embedded in the
<code>.wasm</code>. NotiChess ships these four files as published in the
release (<a href="https://github.com/nmrugg/stockfish.js/releases/tag/$VERSION_JS">github.com/nmrugg/stockfish.js/releases/tag/$VERSION_JS</a>),
without any modification.</p>
</section>

<section lang="fr">
<h1>Stockfish 18 dans NotiChess : code source</h1>
<p>L'app mobile NotiChess contient le moteur d'échecs Stockfish, logiciel libre
sous licence publique générale GNU, version 3 (GPL v3). Le moteur tourne comme
un programme séparé, avec lequel l'app échange des commandes texte UCI. Ce
dossier contient la source correspondante complète du moteur livré dans l'app,
comme l'exige la GPL v3. Le texte de la licence est dans chaque archive
(<code>Copying.txt</code>) et dans la page des licences de l'app.</p>

<h2>Ce que l'app livre</h2>
<ul>
<li><strong>Android</strong> : Stockfish 18, release <code>$VERSION</code> du
projet officiel (<a href="https://github.com/official-stockfish/Stockfish">github.com/official-stockfish/Stockfish</a>),
compilé par NotiChess depuis les sources officielles, sans aucune modification,
sous le nom <code>libstockfish.so</code> pour <code>arm64-v8a</code>
(<code>ARCH=armv8</code>) et <code>armeabi-v7a</code>
(<code>ARCH=armv7-neon</code>). Licence : GPL v3.</li>
<li><strong>iOS</strong> : Stockfish.js 18, release <code>$VERSION_JS</code> de
<a href="https://github.com/nmrugg/stockfish.js">github.com/nmrugg/stockfish.js</a>
(Chess.com et Nathan Rugg, d'après Stockfish) : <code>$JS_MULTI</code>,
<code>$WASM_MULTI</code>, <code>$JS_MONO</code> et <code>$WASM_MONO</code>,
tels que publiés, sans aucune modification. Licence : GPL v3.</li>
</ul>
<p>Sur les deux plateformes, les deux réseaux NNUE ci-dessous sont inclus dans
le moteur à la compilation, et livrés avec lui.</p>

<h2>Fichiers</h2>
<table>
<tr><th>Fichier</th><th>Contenu</th><th>SHA-256</th></tr>
$(ligne "$ARCHIVE" "Archive officielle de la release $VERSION de Stockfish : sources (<code>stockfish/src</code>), licence (<code>stockfish/Copying.txt</code>), auteurs (<code>stockfish/AUTHORS</code>). Son binaire précompilé ne sert pas.")
$(ligne "$GRAND_RESEAU" "Grand réseau NNUE, nommé dans <code>src/evaluate.h</code> des deux sources.")
$(ligne "$PETIT_RESEAU" "Petit réseau NNUE, nommé dans <code>src/evaluate.h</code> des deux sources.")
$(ligne "$ARCHIVE_JS" "Sources de Stockfish.js 18 : l'archive GitHub du tag <code>$VERSION_JS</code> (<code>src</code>, <code>build.js</code>, licence <code>Copying.txt</code>).")
$(ligne moteur.sh "Le script de NotiChess qui télécharge, vérifie et compile le moteur Android, et copie le moteur iOS dans l'app.")
</table>
<p>Pour les vérifier : <code>shasum -a 256 -c SHA256SUMS</code>
(<a href="SHA256SUMS">SHA256SUMS</a>).</p>

<h2>Compiler le moteur Android</h2>
<p>Extraire <code>stockfish/src</code> et <code>stockfish/scripts</code> de
<code>$ARCHIVE</code> (le Makefile lance <code>../scripts/net.sh</code>), et
copier les deux fichiers <code>.nnue</code> dans <code>stockfish/src</code>.
Puis, dans <code>stockfish/src</code>, avec
les outils du NDK Android qu'utilise Flutter (<code>flutter.ndkVersion</code>)
dans le <code>PATH</code>, pour chaque ABI :</p>
<pre>env -u CXXFLAGS -u LDFLAGS -u DEPENDFLAGS -u EXTRACXXFLAGS -u COMPCXX \\
  make -j&lt;N&gt; build ARCH=&lt;armv8|armv7-neon&gt; COMP=ndk KERNEL=Linux \\
  EXTRALDFLAGS="$DRAPEAUX_EDITION"</pre>
<p>puis <code>llvm-strip stockfish</code>. <code>&lt;N&gt;</code> est le nombre
de tâches parallèles, sans effet sur le binaire. Seuls des drapeaux de
compilation et d'édition de liens diffèrent de la compilation de la release
officielle : l'alignement sur des pages de 16 Ko, qu'exigent Android 15 et
Google Play ; <code>KERNEL=Linux</code>, sans quoi un hôte macOS ajoute
<code>-mdynamic-no-pic</code> ; <code>build</code> au lieu de
<code>profile-build</code>, dont l'étape de profilage exécuterait le binaire
Android sur l'hôte.</p>
<p><code>moteur.sh</code> fait tout cela : rangé dans un dossier
<code>scripts</code>, <code>scripts/moteur.sh android &lt;dossier du NDK&gt;</code>
vérifie les trois fichiers de Stockfish ci-dessus, compile les deux ABI et
écrit chaque <code>libstockfish.so</code> sous
<code>android/app/src/main/jniLibs/</code>. Il télécharge ces fichiers depuis
leurs sources d'origine, sauf s'ils sont déjà dans
<code>.cache/moteur/sf_18/</code>, à côté du dossier <code>scripts</code> : y
ranger les copies de cette page, et rien n'est téléchargé.</p>

<h2>Construire le moteur iOS</h2>
<p>Extraire <code>$ARCHIVE_JS</code> et copier les deux fichiers
<code>.nnue</code> dans son dossier <code>src</code> (la construction les
télécharge sinon). Avec Node.js, make et emscripten 3.1.7 installés et dans le
<code>PATH</code>, lancer, dans le dossier extrait,
<code>./build.js --all --only-single --only-standard</code>
(<code>./build.js --help</code> en donne les options ; sans les deux options
<code>--only</code>, les autres éditions demandent des réseaux qui ne sont pas
fournis ici). Il construit, dans <code>src</code>, <code>$JS_MULTI</code> et
<code>$WASM_MULTI</code> (multi-thread), <code>$JS_MONO</code> et
<code>$WASM_MONO</code> (mono-thread), avec les deux réseaux embarqués dans le
<code>.wasm</code>.
NotiChess livre ces quatre fichiers tels que publiés dans la release
(<a href="https://github.com/nmrugg/stockfish.js/releases/tag/$VERSION_JS">github.com/nmrugg/stockfish.js/releases/tag/$VERSION_JS</a>),
sans aucune modification.</p>
</section>
</body>
</html>
EOF
}

case "${1:-}" in
  android) shift; cible_android "$@" ;;
  ios) shift; cible_ios "$@" ;;
  sources) shift; cible_sources "$@" ;;
  *)
    echo "moteur : cible manquante ou inconnue (${1:-aucune})." >&2
    echo "Usage : scripts/moteur.sh android <dossier du NDK>   (ou ANDROID_NDK_ROOT)" >&2
    echo "        scripts/moteur.sh ios [<dossier .../moteur>]" >&2
    echo "        scripts/moteur.sh sources <dossier absent ou vide>" >&2
    exit 1
    ;;
esac
