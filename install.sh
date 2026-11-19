#!/bin/sh
# Agent Island installer: builds the app with the Swift compiler and installs everything into ~/.island
set -eu
cd "$(dirname "$0")"
DEST="${ISLAND_HOME:-$HOME/.island}"
command -v swiftc >/dev/null 2>&1 || { echo "Swift compiler not found. Run: xcode-select --install"; exit 1; }
# If full Xcode is installed but its licence was never accepted, fall back to the Command Line Tools
if ! xcrun swiftc --version >/dev/null 2>&1 && [ -d /Library/Developer/CommandLineTools ]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
echo "Building Island.app …"
mkdir -p "$DEST/Island.app/Contents/MacOS" "$DEST/bin" "$DEST/hooks" "$DEST/jobs" "$DEST/share"
xcrun swiftc -O -swift-version 5 -parse-as-library Sources/Island.swift -o "$DEST/Island.app/Contents/MacOS/Island.new"
pkill -f "$DEST/Island.app/Contents/MacOS/Island" 2>/dev/null || true
mv "$DEST/Island.app/Contents/MacOS/Island.new" "$DEST/Island.app/Contents/MacOS/Island"
cp Sources/Info.plist "$DEST/Island.app/Contents/Info.plist"
cp bin/island "$DEST/bin/island"; cp hooks/agent_bash_hook.py "$DEST/hooks/"; chmod +x "$DEST/bin/island" "$DEST/hooks/agent_bash_hook.py"
rm -rf "$DEST/share"; mkdir -p "$DEST/share"; cp -R skills "$DEST/share/skills"; cp -R integrations/claude-code/agents "$DEST/share/agents"
mkdir -p "$HOME/.local/bin"; ln -sf "$DEST/bin/island" "$HOME/.local/bin/island"
# bring the island back if jobs are still being tracked
ls "$DEST"/jobs/*.json >/dev/null 2>&1 && open -g "$DEST/Island.app" || true
echo "Installed to $DEST  (CLI: ~/.local/bin/island — make sure ~/.local/bin is on your PATH)"
echo
echo "Try it:            island demo"
echo "Claude Code:       island setup claude"
echo "Codex:             island setup codex"
