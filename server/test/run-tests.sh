#!/bin/bash

# Test Runner Script for Flow Way Server
# This script runs all tests and provides a summary

set -e

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║       Flow Way Test Suite Runner                       ║"
echo "║       Testing Camera Avoidance Routing Algorithm       ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TIME=0

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

# Run all tests
echo -e "${BLUE}[Running Tests]${NC}"
echo ""

run_test "Regression Test: Camera Avoidance Algorithm" "test/regression.ts"
run_test "Integration Test: Dynamic Route Planning" "test/test-route.ts"

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║                    TEST SUMMARY                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))

if [ $TESTS_FAILED -eq 0 ]; then
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
