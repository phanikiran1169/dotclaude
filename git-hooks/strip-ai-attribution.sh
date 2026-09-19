#!/bin/sh
# Strips AI-assistant attribution from a commit message file ($1).
#
# Shared by prepare-commit-msg and commit-msg: only the former still runs under
# --no-verify, only the latter sees text appended after message preparation.
#
# Matched by trailer shape, not a list of known strings: Anthropic has shipped
# new trailer names (Claude-Session) that a literal list did not catch.
# Deliberately narrow so human trailers survive -- a reviewer at the vendor
# (Reviewed-by: Sam <sam@anthropic.com>) is a real co-author, not attribution.

[ -f "$1" ] || exit 0

grep -viE \
    -e '^(claude|anthropic)[a-z-]*:' \
    -e '^[a-z-]+-by:.*noreply@anthropic\.com' \
    -e '^[[:space:]]*.{0,4}generated with \[?claude code' \
    "$1" > "$1.stripped" && mv "$1.stripped" "$1"

exit 0
