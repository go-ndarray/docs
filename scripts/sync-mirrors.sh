#!/bin/sh
# Re-sync the pages that copy files of go-ndarray/ndarray.
#
#   scripts/sync-mirrors.sh <ndarray checkout> <tag>
#
# <ndarray checkout> must be at <tag> (vX.Y.Z); the script refuses otherwise,
# since the "Mirrored from ... at <tag>" lines would then be false.
#
# Each page keeps what is ours -- its front matter, and for performance.md the
# introduction above "## How a pure-Go library can beat NumPy" -- and takes the
# rest from the source verbatim, except for the source's repository-relative
# links, which mean nothing on this site and are rewritten:
#
#   a page this site mirrors     -> that page   (perf.md -> performance.md)
#   a package directory          -> pkg.go.dev at <tag>
#   any other file of the repo   -> github.com/go-ndarray/ndarray/blob/<tag>/...
#
# Then it lists any relative link left, and fails if there is one: a link the
# rules do not know is a link that would break.
#
# security.md is not handled here: its source links files in ways a rule
# cannot know (see the README), so it is re-synced by hand.
set -eu

die() { echo "sync-mirrors.sh: $*" >&2; exit 1; }

[ $# -eq 2 ] || die "usage: $0 <ndarray checkout> <tag>"
nd=$1
tag=$2
printf '%s\n' "$tag" | grep -Eq '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' || die "tag must be vX.Y.Z, not \"$tag\""
head=$(git -C "$nd" rev-parse HEAD) || die "$nd is not a git checkout"
at=$(git -C "$nd" rev-parse "$tag^{commit}") || die "$nd has no tag $tag"
[ "$head" = "$at" ] || die "$nd is not at $tag"

blob="https://github.com/go-ndarray/ndarray/blob/$tag"
pkg="https://pkg.go.dev/github.com/go-ndarray/ndarray@$tag"
pages=content/en

# links: rewrite the source's repository-relative links (stdin -> stdout).
# The source files live in docs/, so ../X is the repository root.
links() {
	sed -E \
		-e "s#\]\(perf\.md(\#[^)]*)?\)#](performance.md\1)#g" \
		-e "s#\]\(plan-ndarray\.md(\#[^)]*)?\)#](roadmap.md\1)#g" \
		-e "s#\]\(design-dtypes\.md(\#[^)]*)?\)#](dtypes.md\1)#g" \
		-e "s#\]\(\.\./(linalg|random|fft)/?\)#]($pkg/\1)#g" \
		-e "s#\]\(\.\./([^)]+)\)#]($blob/\1)#g"
}

# front: print a page's front matter, the two --- lines included.
front() {
	awk 'NR == 1 && $0 == "---" { print; inside = 1; next }
	     inside { print; if ($0 == "---") exit }' "$1"
}

# mirror <page> <source in docs/>: front matter, a "Mirrored from" line, then
# the source without its # title (the front matter's title replaces it).
mirror() {
	page=$pages/$1
	src=$nd/docs/$2
	[ -f "$page" ] || die "$page is missing: write its front matter first"
	[ -f "$src" ] || die "$src is missing"
	fm=$(front "$page")
	[ -n "$fm" ] || die "$page has no front matter"
	{
		printf '%s\n\n' "$fm"
		printf '> Mirrored from [`docs/%s`](%s/docs/%s) at %s.\n' "$2" "$blob" "$2" "$tag"
		sed 1d "$src" | links
	} > "$page.tmp"
	mv "$page.tmp" "$page"
}

mirror roadmap.md plan-ndarray.md
mirror dtypes.md design-dtypes.md
mirror linalg.md linalg.md
mirror random.md random.md

# performance: keep our part above the heading, replace the rest.
perf=$pages/performance.md
{
	sed '/^## How a pure-Go library can beat NumPy/,$d' "$perf"
	sed -n '/^## How a pure-Go library can beat NumPy/,$p' "$nd/docs/perf.md" | links
} > "$perf.tmp"
mv "$perf.tmp" "$perf"

# Every relative link left must name a page of this site. Code is not text:
# `Item[T](a, idx...)` is not a link, so fenced blocks and code spans are
# blanked first (lines kept, so the numbers reported stay right).
prose() {
	awk '/^[[:space:]]*```/ { fence = !fence; print ""; next }
	     fence { print ""; next }
	     { gsub(/`[^`]*`/, ""); print }' "$1"
}
bad=0
for f in roadmap.md dtypes.md linalg.md random.md performance.md; do
	prose "$pages/$f" | grep -noE '\]\([^)h#][^)]*\)' | while IFS=: read -r line link; do
		target=${link#](}
		target=${target%)}
		target=${target%%#*}
		[ -f "$pages/$target" ] || { echo "$pages/$f:$line: $target is not a page of this site" >&2; echo x; }
	done
done | grep -q x && bad=1
[ "$bad" -eq 0 ] || die "relative links left that the rules above do not rewrite"

# The package links point at pkg.go.dev for this tag, and pkg.go.dev answers
# 404 for a version it has not indexed yet: right after tagging, the docs
# PR's link check failed on exactly these, twice (v0.12.0, v0.13.0). Ask it
# to fetch the tag (its "Request" button; the POST may time out while it
# works) and say whether the pages answer yet.
curl -s -o /dev/null -X POST --max-time 60 "https://pkg.go.dev/fetch/github.com/go-ndarray/ndarray@$tag" || true
for p in linalg random fft; do
	code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 30 "$pkg/$p") || code=000
	[ "$code" = 200 ] || echo "sync-mirrors.sh: $pkg/$p answers $code; pkg.go.dev may still be indexing $tag -- re-check before opening the PR" >&2
done
echo "synced from $tag; now set params.ndarray.version in hugo.yaml to $tag"
