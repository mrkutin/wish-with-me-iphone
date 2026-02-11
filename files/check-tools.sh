#!/bin/bash
# scripts/check-tools.sh
# Verify all required development and testing tools are installed
# Run: bash scripts/check-tools.sh

echo "=== Wish With Me — Tool Check ==="
echo ""

PASS=0
FAIL=0

check() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" > /dev/null 2>&1; then
        echo "✅ $name"
        ((PASS++))
    else
        echo "❌ $name — NOT FOUND"
        ((FAIL++))
    fi
}

check "Claude Code CLI" "claude --version"
check "Xcode (xcodebuild)" "xcodebuild -version"
check "iOS Simulator (xcrun simctl)" "xcrun simctl list devices available"
check "Maestro" "maestro --version"
check "Node.js (for Playwright)" "node --version"
check "Playwright" "npx playwright --version"
check "ImageMagick (compare)" "compare --version"
check "xcpretty" "xcpretty --version"
check "Git" "git --version"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "Install missing tools:"
    echo "  Claude Code:  curl -fsSL https://claude.ai/install.sh | bash"
    echo "  Xcode:        Install from App Store"
    echo "  Maestro:      brew install maestro"
    echo "  Playwright:   npm install -D @playwright/test && npx playwright install chromium"
    echo "  ImageMagick:  brew install imagemagick"
    echo "  xcpretty:     gem install xcpretty"
    exit 1
fi

echo "All tools ready! 🚀"
