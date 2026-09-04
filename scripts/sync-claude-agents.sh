#!/bin/sh
# sync-claude-agents.sh — regenerate ~/.claude/agents/subagent-*.md from
# roles/*.md (the runtime-neutral role body) plus a per-role Claude Code
# frontmatter block. POSIX sh, no dependencies. Idempotent: re-running with
# unchanged roles/*.md content reproduces byte-identical output.
#
# Usage: sh scripts/sync-claude-agents.sh

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SKILL_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
ROLES_DIR="$SKILL_DIR/roles"
AGENTS_DIR="${CLAUDE_AGENTS_DIR:-$HOME/.claude/agents}"

mkdir -p "$AGENTS_DIR"

write_agent() {
  role="$1"
  description="$2"
  tools="$3"
  model="$4"
  permission_mode="$5"
  name="subagent-$role"
  role_file="$ROLES_DIR/$role.md"
  out="$AGENTS_DIR/$name.md"
  tmp="$out.tmp.$$"

  if [ ! -f "$role_file" ]; then
    echo "sync-claude-agents: missing $role_file" >&2
    exit 1
  fi

  {
    printf '%s\n' "---"
    printf 'name: %s\n' "$name"
    printf 'description: %s\n' "$description"
    printf 'tools: %s\n' "$tools"
    printf 'model: %s\n' "$model"
    printf 'permissionMode: %s\n' "$permission_mode"
    printf '%s\n' "---"
    printf '\n'
    cat "$role_file"
  } >"$tmp"
  mv "$tmp" "$out"
  echo "wrote $out"
}

# Role  Description  Tools  Model  PermissionMode
write_agent tester \
  "Writes acceptance and architecture-pin tests for the supervised-dev pipeline; never touches production code. Invoked only by the supervised-dev skill." \
  "Read, Edit, Write, Bash, Glob, Grep" "sonnet" "acceptEdits"

write_agent implementer \
  "Fixes production code to pass the tester's tests in the supervised-dev pipeline; never edits tests. Invoked only by the supervised-dev skill." \
  "Read, Edit, Write, Bash, Glob, Grep" "sonnet" "acceptEdits"

write_agent reviewer \
  "Read-only diff reviewer for the supervised-dev pipeline; reports every finding at every severity. Invoked only by the supervised-dev skill." \
  "Read, Bash, Glob, Grep" "sonnet" "dontAsk"

write_agent simplifier \
  "Read-only simplification auditor for the supervised-dev pipeline; finds over-built surface a diff added. Invoked only by the supervised-dev skill." \
  "Read, Bash, Glob, Grep" "sonnet" "dontAsk"
