# docs

[![docs](https://github.com/go-ndarray/docs/actions/workflows/docs.yml/badge.svg)](https://github.com/go-ndarray/docs/actions/workflows/docs.yml)
[![License](https://img.shields.io/badge/license-BSD--3--Clause-047857?style=flat-square)](LICENSE)

**The go-ndarray documentation site**, published at
<https://go-ndarray.github.io/docs/>.

A [Hugo](https://gohugo.io/) site with the [tannevaled/hextra](https://github.com/tannevaled/hextra)
fork of the [Hextra](https://github.com/imfing/hextra) theme, built the same way
as the [go-fileshare documentation](https://github.com/go-fileshare/docs), with
go-ndarray's branding. It documents
[`go-ndarray/ndarray`](https://github.com/go-ndarray/ndarray).

## Versions

A version of the documentation is **the minor version of ndarray it
describes**:

| Source | Published under |
| --- | --- |
| branch `main`, with `params.ndarray.version: v0.9.1` in `hugo.yaml` | `https://go-ndarray.github.io/docs/<MAJOR.MINOR>/`, here `/docs/0.9/` |
| the newest version | also `https://go-ndarray.github.io/docs/latest/` |

`https://go-ndarray.github.io/docs/` redirects to `latest/`. Each push to
`main` replaces the directory of the version it describes, and nothing else.

To document a new ndarray release, change `params.ndarray.version` with the
pages. A patch release (`v0.9.2`) updates `0.9`; a minor release (`v0.10.0`)
publishes `0.10` beside it, `latest` moves to it, and `0.9` stays as it was last
published, with a banner pointing its readers to the latest version.

The version selector in the navbar lists every version from
`docs/versions.json` and opens the same page in the version chosen, else that
version's home.

Versions 0.1 and 0.2 were built with MkDocs and mike before this site moved to
Hugo (0.2 was the label MkDocs kept publishing up to ndarray v0.9.1). Their
directories on `gh-pages` are kept as they were published, and they read the
same `versions.json` (mike's format).

## Mirrored pages

Two pages are copies of files in `go-ndarray/ndarray`, kept verbatim so that
re-syncing them is a copy, not an edit:

| Page | Mirrors | What is ours |
| --- | --- | --- |
| `content/en/performance.md` | [`docs/perf.md`](https://github.com/go-ndarray/ndarray/blob/main/docs/perf.md), from the heading `## How a pure-Go library can beat NumPy` to the end | the front matter, and the introduction and *Where it stands* summary above that heading |
| `content/en/security.md` | [`SECURITY.md`](https://github.com/go-ndarray/ndarray/blob/main/SECURITY.md), from `## Reporting` to the end | the front matter and the `> Mirrored from … at vX.Y.Z` line; repository-relative references are rewritten as GitHub links (`this repository` → `[the repository](https://github.com/go-ndarray/ndarray/security)`, `` `fuzz_test.go` `` → ``[`fuzz_test.go`](https://github.com/go-ndarray/ndarray/blob/main/fuzz_test.go)``, …) |

To re-sync from a checkout of ndarray at tag `vX.Y.Z` (`$ND`):

```sh
# performance: keep our part above the heading, replace the rest
{ sed '/^## How a pure-Go library can beat NumPy/,$d' content/en/performance.md
  sed -n '/^## How a pure-Go library can beat NumPy/,$p' "$ND/docs/perf.md"; } > perf.tmp
mv perf.tmp content/en/performance.md

# security: keep our part above "## Reporting", replace the rest, then
# rewrite the repository-relative references as GitHub links again
{ sed '/^## Reporting/,$d' content/en/security.md
  sed -n '/^## Reporting/,$p' "$ND/SECURITY.md"; } > sec.tmp
mv sec.tmp content/en/security.md
git diff content/en/security.md   # check the links, bump "at vX.Y.Z"
```

then update the version in the `> Mirrored from` line, the *Where it stands*
summary of the performance page if the numbers moved, and
`params.ndarray.version` in `hugo.yaml`.

The mirrored text keeps MkDocs' heading anchors in its in-page links
(`#parallel-gemm-start-once-wait-on-work-2026-10-04`). Where Hugo's anchor for a
heading differs from the one MkDocs made, `layouts/_markup/render-heading.html`
adds MkDocs' as a second anchor, so those links, and links published while the
site was built with MkDocs, keep working without editing the mirrored text.

## Languages

English only, at the root of each version (`/docs/<version>/performance/`).
The content lives in `content/en/` so that a language can be added like on the
go-fileshare site: `content/<lang>/` with the same file names, an
`i18n/<lang>.yaml`, and a `languages.<lang>` entry in `hugo.yaml` (label,
`contentDir`, weight, flag, translated description, date format). Declare a
language only with its content: a declared language without pages is an empty
entry in the switch.

## Layout

| Path | What |
| --- | --- |
| `content/en/` | the pages; `_index.md` is the home, `weight` orders the sidebar |
| `i18n/en.yaml` | the site's strings, beside the theme's |
| `hugo.yaml` | `baseURL`, the ndarray version described, the navbar (version › theme › search › GitHub), the brand mounts |
| `layouts/_partials/custom/version-select.html` | the version selector (reads `versions.json`), from go-fileshare/docs |
| `layouts/_partials/custom/content-begin.html` | the outdated-version banner (reads `versions.json`), as the MkDocs site had |
| `layouts/_markup/render-heading.html` | Hextra's heading, plus MkDocs' anchor where it differs |
| `layouts/_partials/favicons.html` | the brand's favicons |
| `assets/css/custom.css` | the brand green as Hextra's primary colour, the table headers |
| `themes/hextra` | submodule: [tannevaled/hextra](https://github.com/tannevaled/hextra), pinned to a release tag |
| `branding` | submodule: [go-ndarray/brand](https://github.com/go-ndarray/brand) (the mark, its PNGs and ICO) |
| `scripts/publish-version.sh` | puts one build into a `gh-pages` checkout and rewrites `versions.json`, `latest` and the root redirect |

## Writing a page

Each page starts with a title, a one-sentence description, and tags:

```yaml
---
title: "Performance — go-ndarray vs NumPy"
linkTitle: "Performance"
weight: 20
description: "…"
tags: [performance]
---
```

Link to another page by its file (`[Performance](performance.md)`): the theme
resolves it to the page's URL. The build's offline link check fails on a
link, or an anchor, that does not exist.

## Working locally

```sh
git clone --recurse-submodules https://github.com/go-ndarray/docs.git
cd docs
mkdir -p data && sh themes/hextra/scripts/page-history.sh > data/pagehistory.json
hugo server --baseURL http://localhost:1313/docs/0.9/
```

then open <http://localhost:1313/docs/0.9/>. Without a `versions.json` the
selector shows only the current version. Hugo 0.146 or later (CI uses the
version pinned in the workflow); no Python, no Node.

To upgrade the theme: `git -C themes/hextra checkout <tag>` (a tag of the
fork), commit the submodule, and run the production build of the workflow.

## Publication

`.github/workflows/docs.yml`:

| Job | When | What |
| --- | --- | --- |
| `build` | pull requests, `main` | builds with `--baseURL …/docs/<version>/`, checks internal links and anchors (lychee, offline), uploads the site |
| `links` | pull requests, `main` | fetches every external URL the pages name |
| `deploy` | `main` | `scripts/publish-version.sh` into `gh-pages`, then a commit and a push; one deploy at a time |

GitHub Pages serves the `gh-pages` branch.

## Licence

BSD-3-Clause.
