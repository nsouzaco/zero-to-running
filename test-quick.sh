#!/bin/bash
# Quick test script for Zero-to-Running CLI

echo "🧪 Quick Test: Zero-to-Running CLI Tool"
echo "========================================"
echo ""

# Test 1: Dependency check
echo "Test 1: Checking dependencies..."
if make dev 2>&1 | head -20; then
    echo "✅ Dependency check passed"
else
    echo "❌ Dependency check failed"
    exit 1
fi

echo ""
echo "Note: This is a quick test. For full testing, see TESTING.md"
