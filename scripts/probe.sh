#!/usr/bin/env bash
# One check of Приборка's /health: up to 5 tries over ~2.5 minutes, then open or close the outage issue.
set -u
ok=0; body=""
for i in 1 2 3 4 5; do
  body=$(curl -sS -m 20 "$URL" 2>&1)
  if echo "$body" | jq -e '.status == "ok"' >/dev/null 2>&1; then ok=1; break; fi
  [ "$i" -lt 5 ] && sleep 30
done
notify() {
  [ -n "${TG_TOKEN:-}" ] || return 0
  for c in ${TG_CHATS//,/ }; do
    curl -sS -m 15 -o /dev/null "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
      --data-urlencode "chat_id=$c" --data-urlencode "text=$1" || true
  done
}
open=$(gh issue list -R "$GITHUB_REPOSITORY" --label outage --state open --json number --jq '.[0].number // empty')
now=$(TZ=Europe/Moscow date '+%d.%m %H:%M МСК')
if [ "$ok" = 1 ]; then
  echo "$now ok"
  if [ -n "$open" ]; then
    gh issue close "$open" -R "$GITHUB_REPOSITORY" -c "Снова отвечает с $now."
    notify "✅ Приборка снова отвечает ($now)."
  fi
elif [ -z "$open" ]; then
  echo "$now DOWN: $(echo "$body" | head -c 200)"
  gh issue create -R "$GITHUB_REPOSITORY" --label outage --assignee sudo-make-god \
    --title "Приборка не отвечает ($now)" \
    --body "$(printf '%s не отвечает «status: ok» около 2,5 минуты (5 попыток).\n\nПоследний ответ:\n```\n%s\n```\n\nЧто делать: docs/ops.md в NoeticTask, раздел о /health.' "$URL" "$(echo "$body" | head -c 400)")"
  notify "🔴 Приборка не отвечает ($now). $URL"
else
  echo "$now still down"
fi
