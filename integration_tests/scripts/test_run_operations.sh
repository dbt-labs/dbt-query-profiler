#!/bin/bash
# Test the print_* macros via dbt run-operation
# Usage: ./test_run_operations.sh <target> [dbt_executable]
#
# Examples:
#   ./test_run_operations.sh snowflake
#   ./test_run_operations.sh duckdb /path/to/dbt
#   DBT_BIN=/path/to/dbt ./test_run_operations.sh bigquery
#
# Note: DuckDB tests are limited because logging doesn't persist across sessions.

set -e

TARGET="${1:-duckdb}"
DBT_BIN="${2:-${DBT_BIN:-dbt}}"
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

# DuckDB has session-scoped logging - can't test print_* via separate run-operations
if [ "$TARGET" == "duckdb" ]; then
    echo "Note: DuckDB logging is session-scoped. Run-operation tests are limited."
    echo "      Full integration testing happens via 'dbt build' (same session)."
    echo ""

    skip_test "print_query_history" "DuckDB requires logging enabled in same session"
    skip_test "print_query_history (table filter)" "DuckDB session-scoped"
    skip_test "print_query_sql" "DuckDB session-scoped"
    skip_test "print_query_plan" "DuckDB session-scoped"
    skip_test "print_query_stats" "DuckDB session-scoped"

else
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
        # Try numeric format (Redshift)
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

        # Test print_query_plan (skip for BigQuery)
        if [ "$TARGET" != "bigquery" ]; then
            run_test "print_query_plan (text)" \
                "$DBT_BIN run-operation print_query_plan --args '{query_id: \"$QUERY_ID\", format: text}' --target $TARGET" \
                "."  # Just check it returns something
        else
            skip_test "print_query_plan" "BigQuery doesn't support query plans"
        fi

        # Test print_query_stats
        run_test "print_query_stats (json)" \
            "$DBT_BIN run-operation print_query_stats --args '{query_id: \"$QUERY_ID\"}' --target $TARGET" \
            "."  # Just check it returns something

        run_test "print_query_stats (text)" \
            "$DBT_BIN run-operation print_query_stats --args '{query_id: \"$QUERY_ID\", format: text}' --target $TARGET" \
            "Query ID"
    fi
fi

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
