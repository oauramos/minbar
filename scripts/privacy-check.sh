#!/bin/bash
# Fails when a file in the repo carries something personal: absolute home
# paths, private-network addresses, tailnet names, e-mail addresses. Personal
# words (host names, names, places) are not listed here, which would publish
# them: they live one ERE per line in .privacy-patterns (git-ignored) or the
# file $MINBAR_PRIVACY_PATTERNS names; CI writes it from a secret.
#   scripts/privacy-check.sh          every file git would commit
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

patterns=(
  '/Users/[A-Za-z0-9._-]+'
  '(^|[^0-9.])(192\.168|10\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}'
  '[A-Za-z0-9-]+\.ts\.net'
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
)
extra="${MINBAR_PRIVACY_PATTERNS:-.privacy-patterns}"
if [ -f "$extra" ]; then
  while IFS= read -r line; do
    case "$line" in '' | '#'*) continue ;; esac
    patterns+=("$line")
  done <"$extra"
else
  echo "privacy-check: no $extra, checking the generic patterns only" >&2
fi

files=()
while IFS= read -r f; do
  case "$f" in .privacy-patterns | scripts/privacy-check.sh) continue ;; esac
  [ -f "$f" ] && files+=("$f")
done < <(git ls-files --cached --others --exclude-standard)

status=0
for p in "${patterns[@]}"; do
  if hits=$(grep -nIE -- "$p" "${files[@]}" 2>/dev/null); then
    echo "$hits"
    status=1
  fi
done
[ "$status" = 0 ] && echo "privacy-check: clean (${#files[@]} files, ${#patterns[@]} patterns)"
exit "$status"
