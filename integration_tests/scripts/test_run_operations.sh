#!/bin/bash
# Test the print_* macros via dbt run-operation
# Usage: ./test_run_operations.sh <target> [dbt_executable]
#
# Examples:
#   ./test_run_operations.sh snowflake
#   ./test_run_operations.sh duckdb /path/to/dbt
#   DBT_BIN=/path/to/dbt ./test_run_operations.sh bigquery
#
# Note: DuckDB uses file-based logging for cross-session persistence.

set -e

TARGET="${1:-duckdb}"
DBT_BIN="${2:-${DBT_BIN:-dbt}}"
# Adapter type may differ from target name (e.g. target "bq" = adapter "bigquery")
ADAPTER="${3:-$TARGET}"
FAILED=0
TESTS_RUN=0
SKIPPED=0

echo "Using dbt: $DBT_BIN"
echo "==================================="
echo "Testing run-operations for: $TARGET"
echo "==================================="
echo ""

# Helper function to run a test
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_pattern="$3"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing $test_name... "

    output=$(eval "$command" 2>&1) || {
        echo "FAIL (command error)"
        echo "  Command: $command"
        echo "  Output: $output"
        FAILED=$((FAILED + 1))
        return 1
    }

    if echo "$output" | grep -qi "$expected_pattern"; then
        echo "PASS"
        return 0
    else
        echo "FAIL (pattern not found)"
        echo "  Expected pattern: $expected_pattern"
        echo "  Output (last 500 chars): ...${output: -500}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

skip_test() {
    local test_name="$1"
    local reason="$2"
    echo "SKIP $test_name ($reason)"
    SKIPPED=$((SKIPPED + 1))
}

# Helper for tests that are expected to FAIL (e.g. mutual-exclusion validation).
# Unlike run_test, this always returns 0 - under `set -e`, a bare top-level call
# that returned 1 on failure would abort the whole script before the summary prints.
run_test_expect_error() {
    local test_name="$1"
    local command="$2"
    local expected_pattern="$3"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing $test_name... "

    if output=$(eval "$command" 2>&1); then
        echo "FAIL (command succeeded, expected it to fail)"
        echo "  Command: $command"
        echo "  Output (last 500 chars): ...${output: -500}"
        FAILED=$((FAILED + 1))
        return 0
    fi

    if echo "$output" | grep -qi "$expected_pattern"; then
        echo "PASS"
        return 0
    else
        echo "FAIL (error message did not match)"
        echo "  Expected pattern: $expected_pattern"
        echo "  Output (last 500 chars): ...${output: -500}"
        FAILED=$((FAILED + 1))
        return 0
    fi
}

# All adapters use the same test flow
if [ "$ADAPTER" == "duckdb" ]; then
    echo "Note: DuckDB uses file-based logging for cross-session persistence."
    echo ""
fi

# Test print_query_history
run_test "print_query_history" \
    "$DBT_BIN run-operation print_query_history --args '{limit: 1}' --target $TARGET" \
    "query_id"

# Test print_query_history with table filter
run_test "print_query_history (table filter)" \
    "$DBT_BIN run-operation print_query_history --args '{table_name: test_query_profiler_marker, limit: 1}' --target $TARGET" \
    "query_id"

# Get a query_id for subsequent tests
echo ""
echo "Getting query_id for further tests..."
QUERY_ID_OUTPUT=$($DBT_BIN run-operation print_query_history --args '{table_name: test_query_profiler_marker, limit: 1}' --target "$TARGET" 2>&1)

# Extract query_id from JSON output (handles both formats)
QUERY_ID=$(echo "$QUERY_ID_OUTPUT" | grep -o '"query_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"query_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$QUERY_ID" ]; then
    # Try numeric format (Redshift, DuckDB)
    QUERY_ID=$(echo "$QUERY_ID_OUTPUT" | grep -o '"query_id"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | sed 's/.*"query_id"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/')
fi

if [ -z "$QUERY_ID" ]; then
    echo "WARNING: Could not extract query_id. Skipping query_id-based tests."
    echo "Output was: $QUERY_ID_OUTPUT"
else
    echo "Using query_id: $QUERY_ID"
    echo ""

    # Test print_query_sql
    run_test "print_query_sql" \
        "$DBT_BIN run-operation print_query_sql --args '{query_id: \"$QUERY_ID\"}' --target $TARGET" \
        "test_query_profiler_marker"

    # Test print_query_plan (skip for BigQuery - takes sql parameter, not query_id)
    if [ "$ADAPTER" != "bigquery" ]; then
        run_test "print_query_plan (text)" \
            "$DBT_BIN run-operation print_query_plan --args '{sql: \"SELECT 1\", format: text}' --target $TARGET" \
            "."  # Just check it returns something
    else
        skip_test "print_query_plan" "BigQuery doesn't support query plans"
    fi

    # Test print_execution_plan
    run_test "print_execution_plan" \
        "$DBT_BIN run-operation print_execution_plan --args '{query_id: \"$QUERY_ID\"}' --target $TARGET" \
        "."  # Just check it returns something

    # Test print_query_stats
    run_test "print_query_stats (json)" \
        "$DBT_BIN run-operation print_query_stats --args '{query_id: \"$QUERY_ID\"}' --target $TARGET" \
        "."  # Just check it returns something

    run_test "print_query_stats (text)" \
        "$DBT_BIN run-operation print_query_stats --args '{query_id: \"$QUERY_ID\", format: text}' --target $TARGET" \
        "Query ID"
fi

echo ""
echo "Testing model_name resolution..."
echo ""

# model_name happy path - asserts on content (the marker embedded in setup_test_queries'
# SQL), not just exit status, so a resolution macro that silently returns the wrong
# statement (or no statement) is caught, not just one that errors outright.
run_test "print_query_sql (model_name)" \
    "$DBT_BIN run-operation print_query_sql --args '{model_name: setup_test_queries}' --target $TARGET" \
    "test_query_profiler_marker"

# model_name and node_id are mutually exclusive - must fail with the expected message,
# not silently pick one or the other.
run_test_expect_error "print_query_sql (model_name + node_id mutual exclusion)" \
    "$DBT_BIN run-operation print_query_sql --args '{model_name: setup_test_queries, node_id: \"model.dbt_query_profiler_integration_tests.setup_test_queries\"}' --target $TARGET" \
    "exactly one of query_id, model_name or node_id"

echo ""
echo "==================================="
echo "Results: $((TESTS_RUN - FAILED))/$TESTS_RUN passed, $SKIPPED skipped"
echo "==================================="

if [ $FAILED -gt 0 ]; then
    echo "FAILED: $FAILED test(s) failed"
    exit 1
else
    echo "SUCCESS: All applicable tests passed"
    exit 0
fi
