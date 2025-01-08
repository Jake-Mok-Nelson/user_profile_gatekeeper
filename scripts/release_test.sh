#!/bin/bash

# Unit tests for release.sh script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/test_release_${RANDOM}_$(date +%s)"

setup() {
    mkdir -p "$TEST_DIR"
    echo "version: 1.0.0" > "$TEST_DIR/pubspec.yaml"
    echo -e "## 1.0.0\n- Initial release" > "$TEST_DIR/CHANGELOG.md"
    git init "$TEST_DIR" --quiet
    cd "$TEST_DIR"
    git add pubspec.yaml CHANGELOG.md >/dev/null
    git commit -m "Initial commit" --quiet
}

teardown() {
    cd ..
    rm -rf "$TEST_DIR"
}

test_missing_pubspec() {
    setup
    rm "$TEST_DIR/pubspec.yaml"
    if "$SCRIPT_DIR/release.sh" "$TEST_DIR" "--dry-run" 2>&1 | grep -q "pubspec.yaml not found"; then
        echo "✓ Missing pubspec test passed"
    else
        echo "✗ Missing pubspec test failed"
        exit 1
    fi
    teardown
}

# Test missing CHANGELOG.md entry, an entry must exist for each version we want to release
test_invalid_semver_strict() {
    setup
    echo "version: 1.0.0-beta" > "$TEST_DIR/pubspec.yaml"
    if "$SCRIPT_DIR/release.sh" "$TEST_DIR" "--strict" "--dry-run" 2>&1 | grep -q "is not a valid semver"; then
        echo "✓ Invalid semver with strict flag test passed"
    else
        echo "✗ Invalid semver with strict flag test failed"
        exit 1
    fi
    teardown
}

# Test that the script does not tag the repo when the --dry-run flag is passed
test_dry_run_no_tag_on_dry_run() {
    setup
    "$SCRIPT_DIR/release.sh" "$TEST_DIR" "--dry-run" >/dev/null
    if ! git rev-parse "v1.0.0" >/dev/null 2>&1; then
        echo "✓ Dry run does not create a git tag"
    else
        echo "✗ Dry run should not create a git tag"
        exit 1
    fi
    teardown
}

# Test that the script exists with an error when the --strict flag is passed the version contains anything other
# than major.minor.patch
test_tag_already_exists() {
    setup
    git tag "1.2.0"
    echo "version: 1.0.0" > "$TEST_DIR/pubspec.yaml"
    if "$SCRIPT_DIR/release.sh" "$TEST_DIR" "--dry-run" 2>&1 | grep -q "already exists as a git tag"; then
        echo "✓ Tag already exists test passed"
    else
        echo "✗ Tag already exists test failed"
        exit 1
    fi
    teardown
}

test_flag_order_strict_then_dry_run() {
    setup
    if "$SCRIPT_DIR/release.sh" "$TEST_DIR" "--dry-run" "--strict" | grep -q "Release simulation completed"; then
        echo "✓ Flag order test passed"
    else
        echo "✗ Flag order test failed"
        exit 1
    fi
    teardown
}

test_flag_order_dry_run_then_strict() {
    setup
    if "$SCRIPT_DIR/release.sh" "$TEST_DIR" "--dry-run" "--strict" | grep -q "Release simulation completed"; then
        echo "✓ Flag order test passed"
    else
        echo "✗ Flag order test failed"
        exit 1
    fi
    teardown
}

test_help_output() {
    setup
    if "$SCRIPT_DIR/release.sh" "--help" | grep -q "Usage:"; then
        echo "✓ Help output test passed"
    else
        echo "✗ Help output test failed"
        exit 1
    fi
    teardown
}

# Run all tests
echo "Running release.sh tests..."
echo "---------------------------------"
for test_func in $(compgen -A function | grep "^test_"); do
    echo "--- Running $test_func"
    $test_func
done
echo "All tests completed."