#!/usr/bin/env bash
# Update the Bitcoin Core subtree in depend/bitcoin to a release tag.
#
# Usage: contrib/update-bitcoin-subtree.sh <tag>    e.g. contrib/update-bitcoin-subtree.sh v33.0
#
# Afterwards run `zig build test`: the header conformance test reports every
# declaration in src/c.zig that no longer matches the new bitcoinkernel.h.

set -euo pipefail

readonly REMOTE="https://github.com/bitcoin/bitcoin.git"
readonly PREFIX="depend/bitcoin"

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <tag>" >&2
    exit 1
fi
readonly TAG="$1"

cd "$(git rev-parse --show-toplevel)"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "error: working tree is not clean" >&2
    exit 1
fi

git subtree pull --prefix="$PREFIX" "$REMOTE" "$TAG" --squash \
    -m "Update Bitcoin Core subtree in $PREFIX to $TAG"
