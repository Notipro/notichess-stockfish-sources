# Stockfish 18 in NotiChess: corresponding source

*Français plus bas.*

The NotiChess mobile app ships the Stockfish chess engine, free software under
the GNU General Public License, version 3 ([LICENSE](LICENSE)): Stockfish
18 compiled from the official sources on Android, and Stockfish.js
18 (WebAssembly build by Chess.com) on iOS, both unmodified. This
repository is the complete corresponding source of what the app ships, as
required by section 6 of the GPL v3.

The GPL covers Stockfish and Stockfish.js only. The engine runs as a separate
program, with which the app exchanges UCI text commands: together they form an
aggregate, and the license of the engine does not extend to the app.

## Files

In this repository: `moteur.sh`, the script that downloads, checks and
compiles the Android engine and copies the iOS engine into the app;
`index.html`, the detailed description of what is shipped and how to rebuild
it; `SHA256SUMS`, the checksums of every file.

In the [`stockfish-18` release](https://github.com/Notipro/notichess-stockfish-sources/releases/tag/stockfish-18):

- `stockfish-android-armv8.tar`
- `nn-c288c895ea92.nnue`
- `nn-37f18f62d772.nnue`
- `stockfish.js-v18.0.0.tar.gz`

## Rebuilding

1. Download the release files next to `SHA256SUMS`, then check them:
   `shasum -a 256 -c SHA256SUMS`.
2. Android: put `moteur.sh` in a `scripts` folder, and the Stockfish
   archive and both `.nnue` networks in `.cache/moteur/sf_18/`, next
   to that `scripts` folder. `scripts/moteur.sh android <Android NDK folder>` checks them and
   compiles every ABI, without downloading anything.
3. iOS: extract the Stockfish.js archive, copy both `.nnue` networks into
   its `src` folder, and run `./build.js --all --only-single --only-standard`
   with Node.js, make and emscripten 3.1.7.

`index.html` gives the exact compiler flags and every detail.

---

# Stockfish 18 dans NotiChess : source correspondante

L'app mobile NotiChess livre le moteur d'échecs Stockfish, logiciel libre sous
licence publique générale GNU, version 3 ([LICENSE](LICENSE)) : Stockfish
18 compilé depuis les sources officielles sur Android, et Stockfish.js
18 (build WebAssembly de Chess.com) sur iOS, tous deux sans
modification. Ce dépôt est la source correspondante complète de ce que l'app
livre, comme l'exige la section 6 de la GPL v3.

La GPL ne couvre que Stockfish et Stockfish.js. Le moteur tourne comme un
programme séparé, avec lequel l'app échange des commandes texte UCI : ils
forment un agrégat, et la licence du moteur ne s'étend pas à l'app.

## Fichiers

Dans ce dépôt : `moteur.sh`, le script qui télécharge, vérifie et compile le
moteur Android, et copie le moteur iOS dans l'app ; `index.html`, la
description détaillée de ce qui est livré et de la façon de le reconstruire ;
`SHA256SUMS`, les empreintes de chaque fichier.

Dans la [Release `stockfish-18`](https://github.com/Notipro/notichess-stockfish-sources/releases/tag/stockfish-18) :

- `stockfish-android-armv8.tar`
- `nn-c288c895ea92.nnue`
- `nn-37f18f62d772.nnue`
- `stockfish.js-v18.0.0.tar.gz`

## Reconstruire

1. Télécharger les fichiers de la Release à côté de `SHA256SUMS`, puis les
   vérifier : `shasum -a 256 -c SHA256SUMS`.
2. Android : ranger `moteur.sh` dans un dossier `scripts`, et l'archive de
   Stockfish et les deux réseaux `.nnue` dans `.cache/moteur/sf_18/`,
   à côté de ce dossier `scripts`. `scripts/moteur.sh android <dossier du NDK Android>` les vérifie
   et compile chaque ABI, sans rien télécharger.
3. iOS : extraire l'archive de Stockfish.js, copier les deux réseaux `.nnue`
   dans son dossier `src`, et lancer
   `./build.js --all --only-single --only-standard` avec Node.js, make et
   emscripten 3.1.7.

`index.html` donne les drapeaux de compilation exacts et tous les détails.
