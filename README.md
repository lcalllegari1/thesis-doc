# Thesis

Typst sources for **Architectural Trade-offs in Zero-Knowledge Proof Decomposition** by Leonardo Callegari.

## Build

Install Typst **0.15.0** (the version used to verify this project), then run:

```sh
./build.sh
```

This writes the complete thesis to `thesis.pdf`. To choose another output path:

```sh
./build.sh /path/to/thesis.pdf
```

The equivalent command, run from this directory, is:

```sh
typst compile --root . --font-path assets/fonts --ignore-system-fonts \
  --package-path vendor/packages main.typ thesis.pdf
```

The required fonts and package runtime files are included. Compilation requires no package downloads or installed system fonts; Typst's built-in fonts remain enabled.

## Contents

- `main.typ`: document entry point.
- `thesis.pdf`: the complete compiled thesis, included in the repository.
- `template.typ`, `theme/`: layout, typography, and shared helpers.
- `include/`: title page, front matter, chapter assembly, appendix slot, and references.
- `thesis/`: all seven chapters and the bibliography.
- `assets/`: the background, 15 figures used in the document, and fonts. Title-page logos are in `include/assets/`.
- `vendor/lovelace/`: the existing local pseudocode package.
- `vendor/packages/preview/`: runtime dependencies for CeTZ 0.5.2, Showybox 2.0.4, and Oxifmt 1.0.0.

Third-party licenses are stored alongside their fonts and packages. The package directories contain only files loaded by this thesis, their manifests, and license notices; they are not full upstream distributions.

This folder was extracted from the current working sources, including the local front-matter edits. The university logo was moved from `slides/unipd.pdf` to `include/assets/university-logo.pdf` and its title-page reference was updated. The original project was left untouched.

Slides, speeches, experiments, plot generators, unused figures, scratch chapters, conversion tools, caches, and the original Git history are excluded. PDF files under `assets/figures/` and `include/assets/` are required input graphics.

## Verification

Verified with Typst 0.15.0: the complete 137-page document builds with system fonts disabled and an empty package cache. Every reported file dependency is inside this folder. With the PDF creation timestamp fixed, the result is byte-for-byte identical to a build from the original working sources.
