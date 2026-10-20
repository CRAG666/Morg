<p align="center">
  <img src="docs/icon.png" width="128" alt="Morg icon">
</p>

<h1 align="center">Morg</h1>

<p align="center">
  <b>Mobile org</b> — a fast viewer and editor for <a href="https://github.com/nvim-neorg/neorg">Neorg</a> notes on Android,
  rendered the way your Neovim shows them.
</p>

<p align="center">
  <a href="https://github.com/CRAG666/Morg/releases/latest">Download the latest release</a>
</p>

![Neovim (left) and Morg (right) rendering the same file](docs/screenshots/neovim-vs-morg.png)

<p align="center">
  <img src="docs/screenshots/guide-markup.png" width="24%" alt="Inline markup">
  <img src="docs/screenshots/guide-tasks.png" width="24%" alt="Tasks and code">
  <img src="docs/screenshots/guide-light.png" width="24%" alt="Light theme">
  <img src="docs/screenshots/workspace.png" width="24%" alt="Workspace browser">
</p>

## Features

- **Norg parser written in Dart**: headings, lists, quotes, TODO states, definitions, footnotes, ranged and
  verbatim tags (`@code`, `@table`, `@math`, `@image`, `@document.meta`, `|details`, `|comment`), infirm tags
  (`.toc`, `.image`, including SVG), carryover tags (`#name`, `#comment`), task extensions with priorities and
  dates on every detached modifier, delimiters, and all inline markup, including link and free-form modifiers.
- **LaTeX math**: inline `$…$` and `@math` blocks are typeset, not shown as source.
- **Faithful to `core.concealer`**: the same icons, ordered-list formats and TODO glyphs as neorg, and the colors
  of *your* Neovim colorscheme (export it with one command, see [Themes](#themes)).
- **Configured like neorg**: `morg.json` has the same structure as `require("neorg").setup()`
  (`core.concealer`, `core.dirman`, `core.esupports.metagen`, `core.journal`).
- **Workspaces**: local folders (for example synced with Syncthing) and cloud folders through Android's Storage
  Access Framework (Nextcloud, OneDrive, …). Links resolve like `core.esupports.hop`: `$/`, `$name/`, `~/`,
  absolute and relative paths, `{* Heading}`, `{$ definition}`, `{^ footnote}`, `{# generic}` (also `#name`
  tags and `<targets>`), anchors (`[name]`), `{/ external.pdf}`, `file://` and URLs.
- **Edit in place, like `conceallevel=2`**: tap any element and only that element shows its raw Norg source,
  still highlighted (delimiters dimmed like Neovim's insert mode), ready to edit; tap elsewhere to save.
  Tap a heading icon to fold it.
- **Editing**: tap a TODO to cycle it (neorg order, children and parents are updated), edit the whole file,
  `updated:` is refreshed on save like metagen, create notes and today's journal entry.
- **Workspaces from the UI**: add, rename, relocate or remove them; opening a workspace opens its `index.norg`,
  like `:Neorg workspace`.
- **Blazing fast**: a linear-time parser (~65 MiB/s) and a virtualized document view that only builds what is
  on screen, no matter how long the note is.
- **Neorg's own documentation built in**: the home screen opens the Neorg help page and the quick Norg guide
  (cheatsheet) shipped with neorg, rendered by Morg.
- English and Spanish interface, chosen in **Settings → Language** (follows the system by default).

## Install

Download `Morg-vX.Y.Z.apk` from the [latest release](https://github.com/CRAG666/Morg/releases/latest). It works
on every Android architecture, and new releases are signed with the same key, so they install over the previous
version.

On first launch grant **File access** if you keep your notes in a regular folder (Syncthing, local storage), then
tap **Add workspace** and choose the folder. Cloud folders work without that permission.

## Configuration

Everything can be changed in **Settings** (language, theme, colorscheme, concealer icons, author, index file, default
workspace and journal options). Those screens edit `morg.json`, which you can also edit directly in
**Settings → Edit configuration** or replace with **Import configuration** (for example from your synced notes).
Invalid configurations are rejected before they are saved.

```json
{
  "theme": "eyes",
  "theme_mode": "system",
  "language": "system",
  "load": {
    "core.concealer": {
      "config": {
        "icons": {
          "heading": { "icons": ["🌸 ", "🌼 ", "🌺 ", "💠 ", "💮 ", "🪷 "] },
          "list": { "icons": ["✿"] },
          "code_block": { "conceal": true }
        }
      }
    },
    "core.dirman": {
      "config": {
        "workspaces": {
          "notes": "~/Documents/Notes",
          "work": "content://com.android.externalstorage.documents/tree/…"
        },
        "index": "index.norg"
      }
    },
    "core.esupports.metagen": { "config": { "author": "me" } },
    "core.journal": { "config": { "journal_folder": "journal", "strategy": "nested" } }
  }
}
```

- Keys and defaults follow neorg; anything you leave out uses neorg's default (`basic` icon preset).
- `theme`, `theme_mode` (`system`, `light`, `dark`) and `language` (`system`, `en`, `es`) are the only keys outside
  neorg's structure.
- On Android `~` is the shared storage root (`/storage/emulated/0`).
- Use the **same workspace names as in Neovim** so links like `{:$notes/index:}` keep working.
- If a workspace folder is missing on the phone, tap it to pick its location; the name is kept.

### Themes

Morg reads colors from the `@neorg.*` highlight groups (and the treesitter groups for code blocks) of a Neovim
colorscheme. To use yours:

```sh
nvim --headless -c 'luafile tool/export_nvim_theme.lua' any-file.norg   # writes <colorscheme>.json
```

Then **Settings → Import Neovim theme**, and set `"theme": "<colorscheme>"` in `morg.json`. The dark and light
variants are exported together. The bundled default is `eyes`.

## Contributing

Contributions are welcome. Please keep commits, comments and documentation in English.

### Setup

The toolchain is pinned with [mise](https://mise.jdx.dev) in `mise.toml` (Flutter, Java, Android SDK):

```sh
mise install
mise exec -- flutter pub get
mise exec -- flutter run            # on a device, or -d linux / -d chrome
```

### Before opening a pull request

```sh
mise exec -- dart format lib tool
mise exec -- flutter analyze        # must report "No issues found!"
mise exec -- flutter build apk --debug
mise exec -- flutter build web      # cloud folders are stubbed out on the web
```

### Guidelines

- **KISS and DRY.** Prefer the smallest change that solves the problem; extract shared code instead of copying it.
- **Libraries first.** Before writing a parser, list, picker or similar, look for a maintained package on
  [pub.dev](https://pub.dev) and check its version and activity.
- **Measure before optimizing.** `dart run tool/bench_parser.dart <notes-dir>` reports parser throughput
  (compile it with `dart compile exe` for realistic numbers). Keep the parser linear-time and the document view
  virtualized.
- **Parser changes must not change output by accident.** Compare the AST of a corpus of real notes before and
  after the change, and fuzz the new parser against the old one with random inputs full of markup characters.
- **Follow neorg.** When behaviour is unclear, read the neorg sources (`core.concealer`, `core.dirman`,
  `core.esupports.hop`, `core.qol.todo_items`, …) and do what they do.
- **User-facing text** lives in `lib/l10n/app_en.arb` (template) and `lib/l10n/app_es.arb`; run
  `flutter gen-l10n` after editing them.

### Project layout

```
lib/
  norg/            parser (ast.dart, parser.dart) and source edits (TODO cycling, metagen)
  norg_view.dart   virtualized renderer that mimics core.concealer
  config/          concealer configuration with neorg's defaults
  theme/           Neovim highlight groups → Flutter text styles
  highlight/       code highlighting languages (re_highlight) and a BibTeX grammar
  workspace/       note stores (local files and Android SAF) and link resolution
  l10n/            translations
  *_screen.dart    home, workspace browser, document, editor and settings screens
assets/            default config, bundled theme, fonts, Neorg docs and icon sources
tool/              Neovim theme exporter and parser benchmark
```

### Releasing

1. Bump `version:` in `pubspec.yaml`.
2. Commit, then push a tag that matches it: `git tag -a v0.2.0 -m "Morg v0.2.0" && git push origin v0.2.0`.

The [release workflow](.github/workflows/release.yml) checks that the tag matches `pubspec.yaml`, builds the
signed universal APK and publishes the release. It needs the `KEYSTORE_BASE64` and `KEYSTORE_PASSWORD`
repository secrets.

## Acknowledgements

- [Neorg](https://github.com/nvim-neorg/neorg) and the [Norg specification](https://github.com/nvim-neorg/norg-specs).
  `assets/docs/neorg.norg` and `assets/docs/cheatsheet.norg` are Neorg's documentation (GPL-3.0).
- [JetBrains Mono](https://www.jetbrains.com/lp/mono/) (OFL) and the
  [Nerd Fonts](https://www.nerdfonts.com) symbols (MIT); their licenses are in `assets/fonts/`.
- [re_highlight](https://pub.dev/packages/re_highlight), [super_sliver_list](https://pub.dev/packages/super_sliver_list),
  [flutter_math_fork](https://pub.dev/packages/flutter_math_fork), [jovial_svg](https://pub.dev/packages/jovial_svg),
  [saf_util](https://pub.dev/packages/saf_util), [saf_stream](https://pub.dev/packages/saf_stream) and the other
  packages listed in `pubspec.yaml`.
