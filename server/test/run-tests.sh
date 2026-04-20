#!/bin/bash

# Test Runner Script for Flow Way Server
# This script automatically discovers and runs all TypeScript test files in the test directory
# Test files should follow the naming pattern: *.ts (excluding run-tests.sh)

set -e

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║       Flow Way Test Suite Runner                       ║"
echo "║       Auto-discovering Tests                           ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TIME=0
declare -a TEST_FILES

run_test() {
    local test_name=$1
    local test_file=$2
    
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} Running: ${test_name}..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local start_time=$(date +%s)
    
    if npx tsx "$test_file"; then
        local end_time=$(date +%s)
        local duration=$(( (end_time - start_time) ))
        echo ""
        echo -e "${GREEN}✅ ${test_name} PASSED${NC} (${duration}s)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TOTAL_TIME=$((TOTAL_TIME + duration))
    else
        local end_time=$(date +%s)
        local duration=$(( (end_time - start_time) ))
        echo ""
        echo -e "${RED}❌ ${test_name} FAILED${NC} (${duration}s)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TOTAL_TIME=$((TOTAL_TIME + duration))
    fi
    
    echo ""
}

# Check prerequisites
echo -e "${YELLOW}[Checking Prerequisites]${NC}"
echo ""

if ! command -v npx &> /dev/null; then
    echo -e "${RED}❌ npx not found. Please install Node.js.${NC}"
    exit 1
fi

if ! curl -s http://localhost:3000/api/cameras > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Warning: Next.js dev server not detected at http://localhost:3000${NC}"
    echo -e "${YELLOW}   Some tests may fail. Make sure to run: pnpm run dev${NC}"
    echo ""
fi

echo -e "${GREEN}✅ Prerequisites checked${NC}"
echo ""

# Auto-discover test files in the test directory
echo -e "${CYAN}[Auto-discovering Test Files]${NC}"
echo ""

# Find all .ts files in test directory (same directory as this script)
# Exclude .d.ts declaration files and run-tests.sh itself
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

for test_file in $(find "$SCRIPT_DIR" -maxdepth 1 -name "*.ts" -type f ! -name "*.d.ts" | sort); do
    # Skip test runner script itself
    if [[ "$(basename "$test_file")" == "run-tests.sh" ]]; then
        continue
    fi
    
    # Extract test name from file (remove path and .ts)
    test_name=$(basename "$test_file" .ts)
    # Convert snake_case/kebab-case to Title Case
    test_name=$(echo "$test_name" | sed 's/_/ /g' | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
    
    TEST_FILES+=("$test_file|$test_name")
    echo -e "${CYAN}  📝 Found: ${test_name}${NC}"
done

echo ""

# Check if any tests were found
if [ ${#TEST_FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No test files found in test directory${NC}"
    echo ""
    exit 0
fi

echo -e "${BLUE}[Running Tests]${NC}"
echo ""

# Run all discovered tests
for test_entry in "${TEST_FILES[@]}"; do
    IFS='|' read -r test_file test_name <<< "$test_entry"
    run_test "$test_name" "$test_file"
done

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║                    TEST SUMMARY                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))

if [ $TOTAL_TESTS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No tests were executed${NC}"
    exit 0
elif [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo -e "   Total Tests: ${TOTAL_TESTS}"
    echo -e "   Passed: ${TESTS_PASSED}"
    echo -e "   Failed: ${TESTS_FAILED}"
    echo -e "   Total Time: ${TOTAL_TIME}s"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some tests failed!${NC}"
    echo -e "   Total Tests: ${TOTAL_TESTS}"
    echo -e "   Passed: ${TESTS_PASSED}"
    echo -e "   Failed: ${TESTS_FAILED}"
    echo -e "   Total Time: ${TOTAL_TIME}s"
    echo ""
    exit 1
fi

