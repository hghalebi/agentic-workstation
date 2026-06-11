#!/usr/bin/env bash
set -euo pipefail

files=(
  install-agentic-tools.sh
  commands.md
)

printf '| File | Line | Command |\n'
printf '| --- | ---: | --- |\n'

for file in "${files[@]}"; do
  [[ -f "$file" ]] || continue
  while IFS=: read -r line text; do
    escaped="${text//|/\\|}"
    printf "| \`%s\` | %s | \`%s\` |\n" "$file" "$line" "$escaped"
  done < <(grep -En '(curl|wget).*(https://|http://)|https://.*\|.*(sh|bash)|go install .*@latest|npm install -g .*@latest|uv tool install .*latest|releases/latest' "$file" || true)
done

echo
echo "Review remote installers against agentic-tools.lock.yaml and docs/remote-installers.md."
