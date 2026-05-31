#!/bin/bash

echo "🧪 Running ALL unit tests from Package.swift testCases..."
echo ""

TEST_TARGETS=($(grep -A 20 "private static let testCases" Packages/MediaListeningSRSApp/Package.swift | grep -E "^\s*\.[A-Z]" | sed 's/.*\.\([^,]*\).*/\1/' | tr -d ' '))

echo "Found ${#TEST_TARGETS[@]} test targets in Package.swift:"
for target in "${TEST_TARGETS[@]}"; do
  echo "  - MSRS.$target"
done
echo ""

DESTINATION="platform=iOS Simulator,name=iPhone 16,OS=18.5"
FAILED_TESTS=()
SKIPPED_TESTS=()

for target in "${TEST_TARGETS[@]}"; do
  scheme="MSRS.$target"
  echo "🧪 Testing $scheme..."

  if xcodebuild test -scheme "$scheme" -destination "$DESTINATION" -quiet 2>/dev/null; then
    echo "✅ $scheme passed"
  else
    if xcodebuild build -scheme "$scheme" -destination "$DESTINATION" 2>&1 | grep -q "does not contain a scheme"; then
      echo "⚠️  $scheme skipped (scheme not found)"
      SKIPPED_TESTS+=("$scheme")
    else
      echo "❌ $scheme failed"
      FAILED_TESTS+=("$scheme")
    fi
  fi
  echo ""
done

echo "📊 Test Summary:"
echo "Total targets: ${#TEST_TARGETS[@]}"
echo "Passed: $((${#TEST_TARGETS[@]} - ${#FAILED_TESTS[@]} - ${#SKIPPED_TESTS[@]}))"
echo "Failed: ${#FAILED_TESTS[@]}"
echo "Skipped: ${#SKIPPED_TESTS[@]}"

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
  echo ""
  echo "❌ Failed tests:"
  for failed in "${FAILED_TESTS[@]}"; do
    echo "  - $failed"
  done
fi

if [ ${#SKIPPED_TESTS[@]} -gt 0 ]; then
  echo ""
  echo "⚠️  Skipped tests (need scheme creation):"
  for skipped in "${SKIPPED_TESTS[@]}"; do
    echo "  - $skipped"
  done
fi

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
  exit 1
else
  echo ""
  echo "🎉 All available tests passed!"
  exit 0
fi
